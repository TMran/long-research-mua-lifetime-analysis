#!/bin/bash
# run_lifetimesMUA.sh
# Generate lifetime_summary.txt by calling ionlifeMUA.py on each ion file.

# uses CAL as default, but you can use a different ion by the following usage
# $ bash run_lifetimesMUA.sh MG
IONNAME="${1:-CAL}"

# Crash prevention
example=$(ls "${IONNAME}"*mindist.xvg 2>/dev/null | head -n1)

if [[ -z "$example" ]]; then
    echo "No files found matching ${IONNAME}*mindist.xvg"
    exit 1
fi

printf "%-25s %-8s %-8s %-8s %-12s %-8s\n" \
       "Ion" "Count" "Min(ps)" "Max(ps)" "Mean(ps)" "Std(ps)" \
       > lifetime_summary.txt

for f in "${IONNAME}"*mindist.xvg; do
    ion=${f%%mindist.xvg}

    # Run ionlifeMUA.py and capture its full output
    out=$(./ionlifeMUA.py "$f")

    mapfile -t lines < <(printf "%s\n" "$out")

    count="${lines[0]}"

    # If count is 0, no binding events
    if [[ "$count" == "0" ]]; then
        min="-"
        max="-"
        mean="-"
        std="-"
    else
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

echo "Lifetime summary written to lifetime_summary.txt"