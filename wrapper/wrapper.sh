#!/bin/bash
# wrapper.sh
# Wrapper script for MUA ion lifetime + histogram analysis.
# Goal:
#   1. Create ion list from prod.gro
#   2. Extract selected ion indices from mindist_or.xvg
#   3. Submit Slurm job to run per-ion mindist
#   4. Slurm job then runs lifetime + histogram summaries

# =========================
# USER SETTINGS
# =========================

# Ion prefix used in files and residue/atom names
# Default is CAL if no input is given.
# Usage:
#   bash wrapper.sh
#   bash wrapper.sh MG
IONNAME="${1:-CAL}"

# Input files
TRAJ="prod.xtc"
TPR="prod.tpr"
GRO="prod.gro"
TEMPLATE_NDX="template.ndx"
WORK_NDX="index.ndx"

# Existing screening output from:   
# gmx mindist -or
SCREEN_FILE="mindist_or.xvg"

# Analysis settings
CUTOFF="0.6"
START_TIME="100000"
END_TIME="200000"   

# # GROMACS group numbers for per-ion mindist
# # Selection order for per-ion mindist:
# #   C1 first
# #   TAR second
# SURFACE_GROUP_NUM="9"   # C1
# TARGET_GROUP_NUM="13"   # TAR

# Output files
ION_TXT="${IONNAME}.txt"
SELECTED_IONS="selected_ions.txt"
SLURM_SCRIPT="mindist_auto.slurm"

# =========================
# SAFETY CHECKS
# =========================

echo "Checking required files..."

for file in "$TRAJ" "$TPR" "$GRO" "$TEMPLATE_NDX" "$SCREEN_FILE" \
            "ion_index.py" "ionlifeMUA.py" "hionlifeMUA.py" \
            "run_lifetimesMUA.sh" "run_histogramMUA.sh"; do
    if [[ ! -f "$file" ]]; then
        echo "Missing required file: $file"
        exit 1
    fi
done

echo "All required files found."

# =========================
# Get group numbers from template.ndx
# =========================

echo "Getting group numbers from ${TEMPLATE_NDX}..."

python get_group_numbers.py "$TEMPLATE_NDX" "$IONNAME"

if [[ ! -f group_numbers.txt ]]; then
    echo "Failed to create group_numbers.txt"
    exit 1
fi

source group_numbers.txt

echo "Using group numbers:"
echo "  ${ION_GROUP_NAME}: ${ION_GROUP_NUM}"
echo "  ${SURFACE_GROUP_NAME}: ${SURFACE_GROUP_NUM}"
echo "  ${TARGET_GROUP_NAME}: ${TARGET_GROUP_NUM}"





# =========================
# STEP 1: MAKE ION TEXT FILE
# =========================

echo "Creating ${ION_TXT} from ${GRO}..."

grep "$IONNAME" "$GRO" > "$ION_TXT"

# Fix spacing so ion_index.py can parse correctly
sed -i "s/ ${IONNAME}/${IONNAME} /g" "$ION_TXT"

if [[ ! -s "$ION_TXT" ]]; then
    echo "No ions matching ${IONNAME} found in ${GRO}"
    exit 1
fi

# =========================
# STEP 2: GET SELECTED IONS
# =========================

echo "Extracting selected ions from ${SCREEN_FILE}..."

./ion_index.py "$SCREEN_FILE" "$ION_TXT" "$CUTOFF" \
    | awk 'NF >= 2 {print $2}' > "$SELECTED_IONS"

if [[ ! -s "$SELECTED_IONS" ]]; then
    echo "No ions found within cutoff ${CUTOFF}"
    exit 1
fi

echo "Selected ions:"
cat "$SELECTED_IONS"

# =========================
# STEP 3: CREATE SLURM SCRIPT
# =========================

echo "Writing ${SLURM_SCRIPT}..."

cat > "$SLURM_SCRIPT" << EOF
#!/bin/bash
#SBATCH --job-name=${IONNAME}_mindist
#SBATCH --output=${IONNAME}_mindist.out
#SBATCH --error=${IONNAME}_mindist.err
#SBATCH --partition=mlong
#SBATCH --gres=gpu
#SBATCH --mem=4gb
#SBATCH --ntasks-per-node=1
#SBATCH --nodes=1

module purge
module load compiler/gcc/11 gromacs-gpu/2024.1

IONNAME="${IONNAME}"
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

echo "Starting per-ion mindist analysis..."

while read -r i
do
    if [[ -z "\$i" ]]; then
        continue
    fi

    echo "Running ion \$i..."

    cp "\$TEMPLATE_NDX" "\$WORK_NDX"
    sed -i "s/Tar/\${i}/" "\$WORK_NDX"

    gmx mindist -f "\$TRAJ" -s "\$TPR" -n "\$WORK_NDX" \\
        -on "\${IONNAME}\${i}mindist.xvg" \\
        -b "\$START_TIME" -e "\$END_TIME" \\
        -d "\$CUTOFF" -group << GROUPS
\$SURFACE_GROUP_NUM
\$TARGET_GROUP_NUM
GROUPS

done < "\$SELECTED_IONS"

echo "Per-ion mindist complete."

echo "Running lifetime summary..."
bash run_lifetimesMUA.sh "\$IONNAME"

echo "Running histogram summary..."
bash run_histogramMUA.sh "\$IONNAME"

echo "Pipeline complete."
echo "Outputs:"
echo "  lifetime_summary.txt"
echo "  histogram_summary.txt"
EOF

# =========================
# STEP 4: SUBMIT JOB
# =========================

echo "Submitting ${SLURM_SCRIPT}..."

sbatch "$SLURM_SCRIPT"