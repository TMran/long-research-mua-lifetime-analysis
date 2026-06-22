# MUA Ion Lifetime Analysis

Place the scripts with:

```text
prod.gro
prod.tpr
prod.xtc
```

Set `GROMACS_ION_NAME` and `ION_LABEL` in `wrapper.sh`.

Then run:

```bash
bash wrapper.sh
sbatch <ION_LABEL>_mindist_auto.slurm
```

After the Slurm job finishes:

```bash
bash run_lifetimesMUA.sh <ION_LABEL>
bash run_histogramMUA.sh <ION_LABEL>
```

Ion settings:

```text
Calcium:   CAL / CAL
Magnesium: MG  / MG
Strontium: MG  / SR
Barium:    MG  / BAR
```