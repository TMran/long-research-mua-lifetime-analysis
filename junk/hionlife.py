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
nheaderlines = 1 # number of header lines

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
bind = numpy.zeros([N], numpy.float64)
#mua = numpy.zeros([N], numpy.float64)
#bridge = numpy.zeros([N], numpy.float64)

st = 0 # dna only bound
et = 0 # mua only bound
#bb = 0 # both bound
#nb = 0 # none bound
data = []
for (n, line) in enumerate(lines):
    elements = line.split()
    time[n] = elements[0]
    bind[n] = elements[3]
    if (int(bind[n]) == 3 and int(bind[n-1]) != 3 ):
        st = n
    elif (int(bind[n]) != 3 and int(bind[n-1]) == 3):
        et = n
        lifetime = (et - st)*10
        data.append(lifetime)
    #elif (float(dna[n]) >= cutoff) and (float(mua[n]) < cutoff):
     #   bridge[n] = 1 # mua only bound
     #   mb+=1
   # else:
    #    bridge[n] = 0 # none bound
     #   nb+=1
    #print('{:10} {:7} {:7} {:6}'.format(time[n], dna[n], mua[n], bridge[n]))
#numpy.histogram(data, bins = 4)
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
    print("No binding periods detected.")    
#avg_bb = float(bb)/float(N)
#avg_db = float(db)/float(N)
#avg_mb = float(mb)/float(N)
#avg_nb = float(nb)/float(N)
#print('{:8.5f} {:8.5f} {:8.5f} {:8.5f}'.format(avg_bb, avg_db, avg_mb, avg_nb))






