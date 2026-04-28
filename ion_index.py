#!/usr/bin/env python

"""
Given a timeseries of number of DNA-ion contacts, compute max, mean, mode.
Usage:
./ion_index.py or.xvg ion.txt cutoff

or.xvg is mindist -or output file
ion.txt is output of 'grep ion prod.gro > ion.txt' where ion is ion name
cutoff is distance cutoff in nm

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

#energy_filename = 'Eenergies.vacuum.time.txt'
filename1 = sys.argv[1]   # read in file from the command line
filename2 = sys.argv[2]   # read in file from the command line
cutoff = float(sys.argv[3])   # read in file from the command line

nheaderlines = 24 # number of header lines

#=============================================================================================
# Open file for reading.
infile = open(filename1, 'r')

# Read all lines.
lines = infile.readlines()

# Close file.
infile.close()

# Discard header.
lines = lines[nheaderlines:]

# Determine number of timesteps in file.
num_ion = len(lines)
#print N

#Parse data.
data = numpy.zeros([num_ion], numpy.float64)
for (n, line) in enumerate(lines):
    elements = line.split()
    data[n] = elements[1]

# Open file for reading.
infile = open(filename2, 'r')

# Read all lines.
lines = infile.readlines()

# Close file.
infile.close()

#Parse data.
index = numpy.zeros([num_ion], int)
for (n, line) in enumerate(lines):
    elements = line.split()
    index[n] = elements[2]

#bin_count = numpy.zeros([num_bins], int)
#bin_count = numpy.zeros([num_bins], numpy.float64)
saveindex = []
for i in range(num_ion):
    if (data[i] <= cutoff):
        saveindex.append(index[i])
        print(data[i],index[i])
#print(*saveindex, sep=" ")
#print(numpy.std(data))

