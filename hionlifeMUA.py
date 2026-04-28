#!/usr/bin/env python

"""
Given xvg file from bundle command make data to fo histogram plot

./ionlife.py MG*ionbridge.txt >> ion_bridge.txt

"""

#=============================================================================================
# IMPORTS
#=============================================================================================

import sys
import numpy        # for numerical work
import os           # For interacting with the operating system
import math 

#=============================================================================================
# PARAMETERS
#=============================================================================================

filename = sys.argv[1]   # read in file from the command line
#cutoff = float(sys.argv[2])   # read in file from the command line
#print(cutoff)

#=============================================================================================

# Open file for reading.
infile = open(filename, 'r')

# Read all lines, skips top header lines starting with # or @
lines = []
for line in infile:
    if line.startswith('#') or line.startswith('@'):
        continue
    lines.append(line)

# Close file.
infile.close()

#print lines 

# Determine number of histogram bins in file.
N = len(lines)
#print N

#Parse data.
time = numpy.zeros([N], numpy.float64)
bind = numpy.zeros([N], numpy.float64)

st = 0 # dna only bound
et = 0 # mua only bound

data = []
for (n, line) in enumerate(lines):
    elements = line.split()

    if len(elements) < 2: # prevents reading in statistics at bottom
        continue

    time[n] = elements[0]
    bind[n] = elements[1]

    if n == 0: # prevents wrap around at beginning of file
        continue

    current = int(bind[n]) # current binding state
    previous = int(bind[n-1]) # previous binding state, used to determine when binding state changes

    if (current == 1 and previous != 1):
        st = n

    elif (current != 1 and previous == 1):
        et = n
        lifetime = (et - st)*10
        data.append(lifetime)


custom_bins = [10, 20, 100, 300, 1000, 10000, 100010]
hist, bin_edges = numpy.histogram(data, bins = custom_bins)

print(hist)
print(bin_edges)
#print(data)

print(len(data))
if data: 
    print(numpy.min(data))
    print(numpy.max(data))
    print(numpy.mean(data))
    print(numpy.std(data))
else:
    print("No binding periods detected or target was bound the entire time.")