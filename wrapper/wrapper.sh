#!/bin/bash
# wrapper.sh
# Wrapper script for MUA ion lifetime + histogram analysis.
#
# Goal:
#   1. Create or validate index.ndx and template.ndx
#   2. Create an ion list from prod.gro
#   3. Extract selected ion indices from mindist_or.xvg
#   4. Create a Slurm job for per-ion gmx mindist calculations
#   5. Run lifetime and histogram summaries after mindist completes
#
# Important naming distinction:
#   GROMACS_ION_NAME = name used inside prod.gro/template.ndx (for example MG)
#   ION_LABEL        = real ion name used in generated output files (for example SR)
#
# Examples:
#   Calcium:   GROMACS_ION_NAME="CAL" and ION_LABEL="CAL"
#   Magnesium: GROMACS_ION_NAME="MG"  and ION_LABEL="MG"
#   Strontium: GROMACS_ION_NAME="MG"  and ION_LABEL="SR"
#   Barium:    GROMACS_ION_NAME="MG"  and ION_LABEL="BAR"

# =========================
# USER SETTINGS
# =========================

# Name used inside GROMACS files and index groups.
GROMACS_ION_NAME="CAL"

# Real ion name used in generated output filenames.
ION_LABEL="CAL"

# Input files
TRAJ="prod.xtc"
TPR="prod.tpr"
GRO="prod.gro"
TEMPLATE_NDX="template.ndx"
WORK_NDX="index.ndx"

# Index group names and the per-ion placeholder
SURFACE_GROUP_NAME="C1"
TARGET_GROUP_NAME="TAR"
TARGET_PLACEHOLDER="Tar"

# Screening output from gmx mindist -or
SCREEN_FILE="mindist_or.xvg"

# Analysis settings
CUTOFF="0.6"
START_TIME="100000"
END_TIME="200000"

# Slurm settings
PARTITION="mlong"
GRES="gpu"
MEMORY="4gb"
NTASKS_PER_NODE="1"
NODES="1"
COMPILER_MODULE="compiler/gcc/11"
GROMACS_MODULE="gromacs-gpu/2024.1"

# Set to "yes" to submit automatically, or "no" for a dry run.
SUBMIT_JOB="no"

# Output files
ION_TXT="${ION_LABEL}.txt"
SELECTED_IONS="selected_ions.txt"
GROUP_NUMBERS_FILE="group_numbers.txt"
SLURM_SCRIPT="${ION_LABEL}_mindist_auto.slurm"

# =========================
# SAFETY CHECKS
# =========================

echo "Checking required files..."

missing_files=()

for file in "$TRAJ" "$TPR" "$GRO" \
            "get_group_numbers.py" "ion_index.py" "ionlifeMUA.py" \
            "hionlifeMUA.py" "run_lifetimesMUA.sh" \
            "run_histogramMUA.sh"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if (( ${#missing_files[@]} > 0 )); then
    echo "Missing required files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo "All required files found."
echo "Internal GROMACS ion name: ${GROMACS_ION_NAME}"
echo "Output ion label: ${ION_LABEL}"

# =========================
# CREATE / VALIDATE INDEX FILES
# =========================

# Return success when an exact index group header exists.
group_exists() {
    local group_name="$1"
    local ndx_file="$2"

    grep -Eq \
        "^[[:space:]]*\[[[:space:]]*${group_name}[[:space:]]*\][[:space:]]*$" \
        "$ndx_file"
}

# Return success when the TAR group contains the literal Tar placeholder.
target_placeholder_exists() {
    local ndx_file="$1"

    awk -v target="$TARGET_GROUP_NAME" -v placeholder="$TARGET_PLACEHOLDER" '
        /^[[:space:]]*\[/ {
            name = $0
            gsub(/^[[:space:]]*\[[[:space:]]*/, "", name)
            gsub(/[[:space:]]*\][[:space:]]*$/, "", name)
            in_target = (name == target)
            next
        }
        in_target {
            value = $0
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value == placeholder) {
                found = 1
                exit
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$ndx_file"
}

# Return success when an XVG file contains at least one data line.
screen_file_has_data() {
    local xvg_file="$1"

    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*@/ { next }
        NF > 0 {
            found = 1
            exit
        }
        END { exit(found ? 0 : 1) }
    ' "$xvg_file"
}

# Load GROMACS only when index creation or editing requires it.
ensure_gmx_available() {
    if command -v gmx >/dev/null 2>&1; then
        return 0
    fi

    echo "gmx was not found. Attempting to load the configured modules..."

    if command -v module >/dev/null 2>&1; then
        module load "$COMPILER_MODULE" "$GROMACS_MODULE"
    fi

    if ! command -v gmx >/dev/null 2>&1; then
        echo "Unable to find gmx."
        echo "Load the GROMACS module, then run the wrapper again."
        exit 1
    fi
}

echo "Preparing ${WORK_NDX} and ${TEMPLATE_NDX}..."

if [[ -f "$TEMPLATE_NDX" ]]; then
    echo "Existing ${TEMPLATE_NDX} found. Validating it..."

    if ! group_exists "$GROMACS_ION_NAME" "$TEMPLATE_NDX"; then
        echo "Missing group [ ${GROMACS_ION_NAME} ] in ${TEMPLATE_NDX}."
        exit 1
    fi

    if ! group_exists "$SURFACE_GROUP_NAME" "$TEMPLATE_NDX"; then
        echo "Missing group [ ${SURFACE_GROUP_NAME} ] in ${TEMPLATE_NDX}."
        exit 1
    fi

    if ! group_exists "$TARGET_GROUP_NAME" "$TEMPLATE_NDX"; then
        echo "Missing group [ ${TARGET_GROUP_NAME} ] in ${TEMPLATE_NDX}."
        exit 1
    fi

    if ! target_placeholder_exists "$TEMPLATE_NDX"; then
        echo "Group [ ${TARGET_GROUP_NAME} ] does not contain ${TARGET_PLACEHOLDER}."
        exit 1
    fi

    # Reset the disposable working index so both files begin identically.
    cp "$TEMPLATE_NDX" "$WORK_NDX"
    echo "Existing index/template files are valid."
else
    echo "${TEMPLATE_NDX} not found. Creating index/template files..."

    if [[ ! -f "$WORK_NDX" ]]; then
        ensure_gmx_available
        echo "Creating default ${WORK_NDX} from ${GRO}..."

        if ! printf "q\n" | gmx make_ndx -f "$GRO" -o "$WORK_NDX"; then
            echo "Failed to create ${WORK_NDX}."
            exit 1
        fi
    else
        echo "Existing ${WORK_NDX} found. Checking required groups..."
    fi

    make_ndx_commands=""

    if ! group_exists "$GROMACS_ION_NAME" "$WORK_NDX"; then
        echo "Adding missing group [ ${GROMACS_ION_NAME} ]."
        make_ndx_commands+="a ${GROMACS_ION_NAME}"$'\n'
    fi

    if ! group_exists "$SURFACE_GROUP_NAME" "$WORK_NDX"; then
        echo "Adding missing group [ ${SURFACE_GROUP_NAME} ]."
        make_ndx_commands+="a ${SURFACE_GROUP_NAME}"$'\n'
    fi

    if [[ -n "$make_ndx_commands" ]]; then
        ensure_gmx_available
        make_ndx_commands+="q"$'\n'
        UPDATED_NDX="${WORK_NDX%.ndx}_updated.ndx"

        if ! printf "%s" "$make_ndx_commands" | \
            gmx make_ndx -f "$GRO" -n "$WORK_NDX" -o "$UPDATED_NDX"; then
            echo "Failed to add required groups to ${WORK_NDX}."
            rm -f "$UPDATED_NDX"
            exit 1
        fi

        mv "$UPDATED_NDX" "$WORK_NDX"
    fi

    if ! group_exists "$GROMACS_ION_NAME" "$WORK_NDX"; then
        echo "Failed to create group [ ${GROMACS_ION_NAME} ] in ${WORK_NDX}."
        exit 1
    fi

    if ! group_exists "$SURFACE_GROUP_NAME" "$WORK_NDX"; then
        echo "Failed to create group [ ${SURFACE_GROUP_NAME} ] in ${WORK_NDX}."
        exit 1
    fi

    # Add the TAR placeholder only when the group does not already exist.
    if group_exists "$TARGET_GROUP_NAME" "$WORK_NDX"; then
        if ! target_placeholder_exists "$WORK_NDX"; then
            echo "Group [ ${TARGET_GROUP_NAME} ] already exists in ${WORK_NDX},"
            echo "but it does not contain the expected ${TARGET_PLACEHOLDER} placeholder."
            echo "Please inspect ${WORK_NDX} manually."
            exit 1
        fi

        echo "Existing [ ${TARGET_GROUP_NAME} ] placeholder group is valid."
    else
        echo "Appending [ ${TARGET_GROUP_NAME} ] placeholder group..."

        {
            echo "[ ${TARGET_GROUP_NAME} ]"
            echo "$TARGET_PLACEHOLDER"
        } >> "$WORK_NDX"
    fi

    cp "$WORK_NDX" "$TEMPLATE_NDX"

    if ! group_exists "$TARGET_GROUP_NAME" "$TEMPLATE_NDX" || \
       ! target_placeholder_exists "$TEMPLATE_NDX"; then
        echo "Failed to create the TAR placeholder in ${TEMPLATE_NDX}."
        exit 1
    fi

    echo "Created ${WORK_NDX} and ${TEMPLATE_NDX}."
fi

# =========================
# CREATE / VALIDATE SCREENING FILE
# =========================

echo "Preparing screening file ${SCREEN_FILE}..."

if [[ -f "$SCREEN_FILE" ]]; then
    echo "Existing ${SCREEN_FILE} found. Validating it..."

    if ! screen_file_has_data "$SCREEN_FILE"; then
        echo "${SCREEN_FILE} exists but contains no data."
        echo "Please inspect or remove it before running the wrapper again."
        exit 1
    fi

    echo "Existing ${SCREEN_FILE} is valid."
else
    ensure_gmx_available

    echo "Creating ${SCREEN_FILE}..."
    echo "  First group:  ${GROMACS_ION_NAME}"
    echo "  Second group: ${SURFACE_GROUP_NAME}"

    if ! printf "%s\n%s\n" \
        "$GROMACS_ION_NAME" \
        "$SURFACE_GROUP_NAME" | \
        gmx mindist \
            -f "$TRAJ" \
            -s "$TPR" \
            -n "$WORK_NDX" \
            -or "$SCREEN_FILE" \
            -b "$START_TIME" \
            -e "$END_TIME" \
            -d "$CUTOFF" \
            -ng 1; then

        echo "Failed to create ${SCREEN_FILE}."
        rm -f "$SCREEN_FILE"
        exit 1
    fi

    if [[ ! -f "$SCREEN_FILE" ]]; then
        echo "GROMACS finished, but ${SCREEN_FILE} was not created."
        exit 1
    fi

    if ! screen_file_has_data "$SCREEN_FILE"; then
        echo "${SCREEN_FILE} was created but contains no data."
        exit 1
    fi

    echo "Created ${SCREEN_FILE} successfully."
fi

# =========================
# GET GROUP NUMBERS
# =========================

echo "Getting group numbers from ${TEMPLATE_NDX}..."

# Remove any old output so a failed run cannot reuse stale values.
rm -f "$GROUP_NUMBERS_FILE"

if ! python get_group_numbers.py "$TEMPLATE_NDX" "$GROMACS_ION_NAME" \
    "$SURFACE_GROUP_NAME" "$TARGET_GROUP_NAME"; then
    echo "Failed to determine GROMACS group numbers."
    exit 1
fi

if [[ ! -f "$GROUP_NUMBERS_FILE" ]]; then
    echo "Failed to create ${GROUP_NUMBERS_FILE}."
    exit 1
fi

source "$GROUP_NUMBERS_FILE"

echo "Using group numbers:"
echo "  ${ION_GROUP_NAME}: ${ION_GROUP_NUM}"
echo "  ${SURFACE_GROUP_NAME}: ${SURFACE_GROUP_NUM}"
echo "  ${TARGET_GROUP_NAME}: ${TARGET_GROUP_NUM}"

# =========================
# STEP 1: MAKE ION TEXT FILE
# =========================

echo "Creating ${ION_TXT} from ${GRO} using internal name ${GROMACS_ION_NAME}..."

grep "$GROMACS_ION_NAME" "$GRO" > "$ION_TXT"

# Fix spacing so ion_index.py can parse correctly.
sed -i "s/ ${GROMACS_ION_NAME}/${GROMACS_ION_NAME} /g" "$ION_TXT"

if [[ ! -s "$ION_TXT" ]]; then
    echo "No ions matching ${GROMACS_ION_NAME} found in ${GRO}."
    exit 1
fi

# =========================
# STEP 2: GET SELECTED IONS
# =========================

echo "Extracting selected ions from ${SCREEN_FILE}..."

./ion_index.py "$SCREEN_FILE" "$ION_TXT" "$CUTOFF" \
    | awk 'NF >= 2 {print $2}' > "$SELECTED_IONS"

if [[ ! -s "$SELECTED_IONS" ]]; then
    echo "No ions found within cutoff ${CUTOFF}."
    exit 1
fi

echo "Selected ions:"
cat "$SELECTED_IONS"

# =========================
# STEP 3: CREATE SLURM SCRIPT
# =========================

echo "Writing ${SLURM_SCRIPT}..."

cat > "$SLURM_SCRIPT" << EOF_SLURM
#!/bin/bash
#SBATCH --job-name=${ION_LABEL}_mindist
#SBATCH --output=${ION_LABEL}_mindist.out
#SBATCH --error=${ION_LABEL}_mindist.err
#SBATCH --partition=${PARTITION}
#SBATCH --gres=${GRES}
#SBATCH --mem=${MEMORY}
#SBATCH --ntasks-per-node=${NTASKS_PER_NODE}
#SBATCH --nodes=${NODES}

module purge
module load ${COMPILER_MODULE} ${GROMACS_MODULE}

ION_LABEL="${ION_LABEL}"
TRAJ="${TRAJ}"
TPR="${TPR}"
TEMPLATE_NDX="${TEMPLATE_NDX}"
WORK_NDX="${WORK_NDX}"
CUTOFF="${CUTOFF}"
START_TIME="${START_TIME}"
END_TIME="${END_TIME}"
SURFACE_GROUP_NUM="${SURFACE_GROUP_NUM}"
TARGET_GROUP_NUM="${TARGET_GROUP_NUM}"
SELECTED_IONS="${SELECTED_IONS}"

echo "Starting per-ion mindist analysis for \${ION_LABEL}..."

while read -r i
do
    if [[ -z "\$i" ]]; then
        continue
    fi

    echo "Running ion \$i..."

    cp "\$TEMPLATE_NDX" "\$WORK_NDX"
    sed -i "s/Tar/\${i}/" "\$WORK_NDX"

    gmx mindist -f "\$TRAJ" -s "\$TPR" -n "\$WORK_NDX" \\
        -on "\${ION_LABEL}\${i}mindist.xvg" \\
        -b "\$START_TIME" -e "\$END_TIME" \\
        -d "\$CUTOFF" -group << GROUPS
\$SURFACE_GROUP_NUM
\$TARGET_GROUP_NUM
GROUPS

done < "\$SELECTED_IONS"

echo "Per-ion mindist complete."

echo "Running lifetime summary..."
bash run_lifetimesMUA.sh "\$ION_LABEL"

echo "Running histogram summary..."
bash run_histogramMUA.sh "\$ION_LABEL"

echo "Pipeline complete."
echo "Outputs:"
echo "  lifetime_summary.txt"
echo "  histogram_summary.txt"
EOF_SLURM

# =========================
# STEP 4: SUBMIT JOB
# =========================

if [[ "$SUBMIT_JOB" == "yes" ]]; then
    echo "Submitting ${SLURM_SCRIPT}..."
    sbatch "$SLURM_SCRIPT"
else
    echo "Dry run complete. Slurm script created but not submitted."
    echo "Review it with: less ${SLURM_SCRIPT}"
    echo "Submit it with: sbatch ${SLURM_SCRIPT}"
fi
