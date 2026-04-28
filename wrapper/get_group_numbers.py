#!/usr/bin/env python3

"""
get_group_numbers.py

Reads a GROMACS index file and finds group numbers for:
- ion group, e.g. CAL or MG
- surface group, default C1
- target group, default TAR

Usage:
    python get_group_numbers.py template.ndx CAL

Output:
    group_numbers.txt
"""

import sys
import re


def clean_group_name(line):
    """
    Extracts group name from lines like:
    [ CAL ]
    [   C1   ]
    """
    match = re.match(r"^\s*\[\s*(.*?)\s*\]\s*$", line)
    if match:
        return match.group(1)
    return None


def main():
    if len(sys.argv) < 3:
        print("Usage: python get_group_numbers.py template.ndx IONNAME [SURFACE_GROUP] [TARGET_GROUP]")
        sys.exit(1)

    ndx_file = sys.argv[1]
    ion_group_name = sys.argv[2]

    surface_group_name = sys.argv[3] if len(sys.argv) > 3 else "C1"
    target_group_name = sys.argv[4] if len(sys.argv) > 4 else "TAR"
    
    output_file = "group_numbers.txt"

    group_numbers = {}
    group_counter = -1

    try:
        with open(ndx_file, "r") as infile:
            for line in infile:
                group_name = clean_group_name(line)

                if group_name is not None:
                    group_counter += 1
                    group_numbers[group_name] = group_counter

    except FileNotFoundError:
        print(f"Error: file not found: {ndx_file}")
        sys.exit(1)

    required_groups = [
        ion_group_name,
        surface_group_name,
        target_group_name,
    ]

    missing = [group for group in required_groups if group not in group_numbers]

    if missing:
        print("Error: missing required group(s):")
        for group in missing:
            print(f"  {group}")
        sys.exit(1)

    ion_group_num = group_numbers[ion_group_name]
    surface_group_num = group_numbers[surface_group_name]
    target_group_num = group_numbers[target_group_name]

    with open(output_file, "w") as outfile:
        outfile.write(f"ION_GROUP_NAME={ion_group_name}\n")
        outfile.write(f"SURFACE_GROUP_NAME={surface_group_name}\n")
        outfile.write(f"TARGET_GROUP_NAME={target_group_name}\n")
        outfile.write(f"ION_GROUP_NUM={ion_group_num}\n")
        outfile.write(f"SURFACE_GROUP_NUM={surface_group_num}\n")
        outfile.write(f"TARGET_GROUP_NUM={target_group_num}\n")

    print(f"Group numbers written to {output_file}")
    print(f"{ion_group_name}: {ion_group_num}")
    print(f"{surface_group_name}: {surface_group_num}")
    print(f"{target_group_name}: {target_group_num}")


if __name__ == "__main__":
    main()