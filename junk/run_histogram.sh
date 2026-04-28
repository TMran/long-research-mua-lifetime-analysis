#!/bin/bash
# run_histogram.sh
# Generate histogram_summary.txt by calling hionlife.py on each ion file,
# and omit ions whose histogram counts are all zero.

# 1) Get bin edges and build header
example=$(ls CAL*ionbridge.txt | head -n1)
out=$(./hionlife.py "$example")
# First line: counts, Second line: bin edges
counts_line=$(echo "$out" | sed -n '1p' | tr -d '[],')
edges_line=$(echo "$out" | sed -n '2p' | tr -d '[],')
# Parse edges into array (splitting on whitespace)
read -ra edges <<< "$edges_line"
# Build human-readable labels
labels=()
for ((i=0; i<${#edges[@]}-1; i++)); do
    labels+=("${edges[i]}–${edges[i+1]}")
done

# Write header to summary file
{
    printf "%s" "Ion"
    for lbl in "${labels[@]}"; do
        printf "\t%s" "$lbl"
    done
    echo
} > histogram_summary2.txt

# 2) Loop over each ion file and append non-zero rows
for f in CAL*ionbridge.txt; do
    ion=${f%%ionbridge.txt}
    out=$(./hionlife.py "$f")
    counts_line=$(echo "$out" | sed -n '1p' | tr -d '[],')
    # Parse counts into array (splitting on whitespace)
    read -ra counts <<< "$counts_line"

    # Check if any count is non-zero
    keep=false
    for c in "${counts[@]}"; do
        if (( c != 0 )); then
            keep=true
            break
        fi
    done

    # Append row if at least one non-zero count
    if $keep; then
        printf "%s" "$ion" >> histogram_summary2.txt
        for c in "${counts[@]}"; do
            printf "\t%s" "$c"
        done >> histogram_summary2.txt
        echo >> histogram_summary2.txt
    fi
done

echo "Filtered histogram summary written to histogram_summary.txt"

