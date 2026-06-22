# Wrapper Script Logic Notes

## Goal

Build a wrapper for the MUA ion lifetime pipeline that reduces manual editing and eventually automates the workflow from GROMACS inputs to summary outputs.

## Current Scope

The wrapper will eventually:

1. Check required files. X
2. Create or validate `template.ndx`. X
3. Add `[ TAR ]` placeholder if missing. X
4. Parse group numbers from `template.ndx`. X
5. Run or reuse `mindist_or.xvg`.
6. Create ion text file from `prod.gro`.
7. Run `ion_index.py`.
8. Save selected ion indices to `selected_ions.txt`.
9. Generate and submit a Slurm job.
10. Run lifetime and histogram summaries.

## Current Design Decisions

- Main wrapper will be written in Bash.
- Group-number parsing will be handled by a separate Python script.
- `template.ndx` should contain:

```text
[ TAR ]
Tar






Required files: prod.xtc, prod.tpr, prod.gro, template.ndx, mindist_or.xvg, and all wrapper/scripts.

$bash wrapper.sh CAL

$sbatch mindist_auto.slurm #current doesn't submit file for testing purposes

squeue -u/p ...

check files

head lifetime_summary.txt
tail lifetime_summary.txt

head histogram_summary.txt
tail histogram_summary.txt

to rerun summaries without rerunning entire wrapper
bash run_lifetimesMUA.sh CAL
bash run_histogramMUA.sh CAL