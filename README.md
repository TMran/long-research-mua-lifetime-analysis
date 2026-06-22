# MUA Ion Lifetime Analysis

Place the scripts with `prod.gro`, `prod.tpr`, and `prod.xtc`.

Set `GROMACS_ION_NAME` and `ION_LABEL` in `wrapper.sh`, 

then run:
bash wrapper.sh
sbatch <ION_LABEL>_mindist_auto.slurm

After the Slurm job finishes:

bash run_lifetimesMUA.sh <ION_LABEL>
bash run_histogramMUA.sh <ION_LABEL>

Ion settings:

GROMACS_ION_NAME="CAL" / ION_LABEL="CAL"

* Calcium: `CAL` / `CAL`
* Magnesium: `MG` / `MG`
* Strontium: `MG` / `SR`
* Barium: `MG` / `BAR`