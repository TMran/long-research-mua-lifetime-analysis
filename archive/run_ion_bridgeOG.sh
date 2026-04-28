#!/bin/bash

for i in CAL*pairdist.xvg; do part1=${i%%pairdist.xvg}; ./ion_bridgeOG.py $i 0.6 >> ${part1}ionbridge.txt; done

