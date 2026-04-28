#!/usr/bin/env python

"""
Given xvg file from bundle command make data to fo histogram plot

./ion_bridge.py pardist.xvg cutoff >> ion_bridge.txt

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
cutoff = float(sys.argv[2])   # read in file from the command line
print(cutoff)
nheaderlines = 25 # number of header lines

#=============================================================================================

# Open file for reading.
infile = open(filename, 'r')

# Read all lines.
lines = infile.readlines()

# Close file.
infile.close()

# Discard header.
lines = lines[nheaderlines:]
#print lines 

# Determine number of histogram bins in file.
N = len(lines)
#print N

#Parse data.
time = numpy.zeros([N], numpy.float64)
dist = numpy.zeros([N], numpy.float64)
state = numpy.zeros([N], numpy.int64)

b = 0 # bound
nb = 0 # unbound

for (n, line) in enumerate(lines):
    elements = line.split()
    time[n] = float(elements[0])
    dist[n] = float(elements[1])
    
    if dist[n] < cutoff:
        state[n] = 1    # bound
        b+=1

    else:
        state[n] = 0    # unbound
        nb+= 1

    # print("time dist state")
    print('{:10.3f} {:7.3f} {:6}'.format(time[n], dist[n], int(state[n])))

# print("bound_frames unbound_frames")
print('{:8} {:8}'.format(b, nb))



avg_b = float(b)/float(N)
avg_nb = float(nb)/float(N)

# print("bound_fraction unbound_fraction")
print('{:8.5f} {:8.5f}'.format(avg_b, avg_nb))