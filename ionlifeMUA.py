#!/usr/bin/env python

"""
Given xvg file from bundle command make data to fo histogram plot

./ionlife.py CAL*ionbridge.txt >> ion_bridge.txt

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

st = 0 # start
et = 0 # end
data = []

for (n, line) in enumerate(lines):
    elements = line.split()

    #print(n, elements) # for debugging

    if len(elements) < 2: # skips summary stats at bottom of file if there are any
        continue

    time[n] = elements[0] # column for simulation time
    bind[n] = elements[1] # column for binding state

    if n == 0: # prevents n-1 issue where first iteration compares itself to the last line of file
        continue

    current = int(bind[n]) # current binding state
    previous = int(bind[n-1]) # previous binding state, used to determine when binding state changes

    if (current == 1 and previous != 1 ): # finds start of binding
        st = n

    elif (current != 1 and previous == 1): # finds end of binding
        et = n
        lifetime = (et - st)*10 # calculates binding time
        data.append(lifetime) # adds event for data

    
#print(data) # for debugging
print(len(data)) # prints number of recorded lifetimes

if data: 
    print(numpy.min(data)) # shortest lifetime
    print(numpy.max(data)) # longest lifetime
    print(numpy.mean(data)) # averafe lifetime
    print(numpy.std(data)) # spread for sd

else:
    print("No binding periods detected or target was binded the entire time.")  