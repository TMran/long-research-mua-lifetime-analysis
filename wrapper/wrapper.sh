#!/bin/bash
# wrapper.sh
# Wrapper script for MUA ion lifetime + histogram analysis.
#
# Goal:
#   1. Create an ion list from prod.gro
#   2. Extract selected ion indices from mindist_or.xvg
#   3. Create a Slurm job for per-ion gmx mindist calculations
#   4. Run lifetime and histogram summaries after mindist completes
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

# Existing screening output from gmx mindist -or
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

for file in "$TRAJ" "$TPR" "$GRO" "$TEMPLATE_NDX" "$SCREEN_FILE" \
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
# GET GROUP NUMBERS
# =========================

echo "Getting group numbers from ${TEMPLATE_NDX}..."

# Remove any old output so a failed run cannot reuse stale values.
rm -f "$GROUP_NUMBERS_FILE"

if ! python get_group_numbers.py "$TEMPLATE_NDX" "$GROMACS_ION_NAME"; then
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

echo "Starting per-ion mindist analysis for \\${ION_LABEL}..."

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
