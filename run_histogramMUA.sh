#!/bin/bash
# run_histogram.sh
# Generate histogram_summary.txt by calling hionlife.py on each ion file,
# and omit ions whose histogram counts are all zero.

# uses CAL as default, but you can use a different ion by the following usage
# $bash run_histogram.sh MG
IONNAME="${1:-CAL}"

# 1) Get bin edges and build header
example=$(ls "${IONNAME}"*mindist.xvg 2>/dev/null | head -n1)

# Crash prevention
if [[ -z "$example" ]]; then
    echo "No files found matching ${IONNAME}*mindist.xvg"
    exit 1
fi

out=$(./hionlifeMUA.py "$example")
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
} > histogram_summary.txt

# 2) Loop over each ion file and append non-zero rows
for f in "${IONNAME}"*mindist.xvg; do
    ion=${f%%mindist.xvg}
    out=$(./hionlifeMUA.py "$f")
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
        printf "%s" "$ion" >> histogram_summary.txt
        for c in "${counts[@]}"; do
            printf "\t%s" "$c"
        done >> histogram_summary.txt
        echo >> histogram_summary.txt
    fi
done

echo "Filtered histogram summary written to histogram_summary.txt"