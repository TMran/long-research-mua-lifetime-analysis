#!/bin/bash
printf "%-25s %-8s %-8s %-8s %-12s %-8s\n" \
       "Ion" "Count" "Min(ps)" "Max(ps)" "Mean(ps)" "Std(ps)" \
       > lifetime_summary.txt

for f in CAL*ionbridge.txt; do
    ion=${f%%ionbridge.txt}

    # Run ionlife.py and capture its full output
    out=$(./ionlife.py "$f")

    mapfile -t lines < <(printf "%s\n" "$out" | tail -n 5)

    # If the first of these five lines contains “No binding periods detected.”,
    # we know there were zero intervals, so fill in placeholders.
    if [[ "${lines[0]}" == *"No binding periods detected."* ]]; then
        count=0
        min="-"
        max="-"
        mean="-"
        std="-"
    else
        # Otherwise, each array element is exactly one of the five numbers:
        count="${lines[0]}"
        min="${lines[1]}"
        max="${lines[2]}"
        mean="${lines[3]}"
        std="${lines[4]}"
    fi

    # Print one fixed-width line into the summary
    printf "%-25s %-8s %-8s %-8s %-12s %-8s\n" \
           "$ion" "$count" "$min" "$max" "$mean" "$std" \
           >> lifetime_summary.txt
done
