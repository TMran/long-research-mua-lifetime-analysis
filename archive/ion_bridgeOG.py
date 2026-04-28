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
dna = numpy.zeros([N], numpy.float64)
mua = numpy.zeros([N], numpy.float64)
bridge = numpy.zeros([N], numpy.float64)

db = 0 # dna only bound
mb = 0 # mua only bound
bb = 0 # both bound
nb = 0 # none bound

for (n, line) in enumerate(lines):
    elements = line.split()
    time[n] = elements[0]
    dna[n] = elements[1]
    mua[n] = elements[2]
    if (float(dna[n]) < cutoff) and (float(mua[n]) < cutoff):
        bridge[n] = 3 # both bound
        bb+=1
    elif (float(dna[n]) < cutoff) and (float(mua[n]) >= cutoff):
        bridge[n] = 2 # dna only bound
        db+=1
    elif (float(dna[n]) >= cutoff) and (float(mua[n]) < cutoff):
        bridge[n] = 1 # mua only bound
        mb+=1
    else:
        bridge[n] = 0 # none bound
        nb+=1
    print('{:10} {:7} {:7} {:6}'.format(time[n], dna[n], mua[n], bridge[n]))

print('{:8} {:8} {:8} {:8}'.format(bb, db, mb, nb))

avg_bb = float(bb)/float(N)
avg_db = float(db)/float(N)
avg_mb = float(mb)/float(N)
avg_nb = float(nb)/float(N)
print('{:8.5f} {:8.5f} {:8.5f} {:8.5f}'.format(avg_bb, avg_db, avg_mb, avg_nb))






