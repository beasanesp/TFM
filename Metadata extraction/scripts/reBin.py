#!/usr/bin/env python3
'''
Run the script as:

    python3 reBin.py -i [BEDfile in] -o [BEDfile out] -o [Desired bin width] -m [Minimum target]
    
'''

import pandas as pd
import itertools
import numpy as np
import statistics
import argparse

def split_targets(bed, med_size, min_size=0):
    """Split large regions into smaller, consecutive regions.
    ----------
    med_size : int
        Split regions into equal-sized subregions of about this size.
        Specifically, subregions are no larger than 150% of this size, no
        smaller than 75% this size, and the average will approach this size when
        subdividing a large region.
    min_size : int
        Drop any regions smaller than this size.
    """
    output = [] 
    # Iterate over the pandas dataframe rows
    for row in bed.itertuples(index=False):
        # Check if we have a fourth column with gene names
        gene = row[3] if len(row) >= 4 else None
        # Size of the target
        size = row[2] - row[1]
        # If the target is longer than the desired size (median by default)
        if size > med_size: 
            # Amount of bins to split the target in
            nbins = int(round(size / med_size)) or 1
            # Return row if the number of bins is 1
            if nbins == 1:
                output.append(row)
            else:
                # Divide the region into equal-sized bins
                bin_size = size / nbins
                bin_start = row[1]
                for i in range(1, nbins):
                    bin_end = row[1] + int(i * bin_size)
                    output.append([row[0], bin_start, bin_end, gene])
                    bin_start = bin_end
                output.append([row[0], bin_start, row[2], gene])
        else:
            output.append(row)
    return(pd.DataFrame(output).dropna(axis=1, how='all'))

########################################################################

parser = argparse.ArgumentParser(description='Split large target bins')

parser.add_argument(
    "-i",
    type=str,
    default=None,
    help="Path of the input bed file")
parser.add_argument(
    "-o",
    type=str,
    default=None,
    help="Path of the output bed file")
parser.add_argument(
    "-b",
    type=int,
    default=None,
    help="Average bin size")
parser.add_argument(
    "-m",
    type=int,
    default=0,
    help="minimum bin size")

args = parser.parse_args()

bedfile = pd.read_csv(args.i, sep='\t', header = None)

des = int(statistics.median(bedfile[2]-bedfile[1])) if args.b == None else args.b

outfile = split_targets(bedfile, 
                        med_size = des, 
                        min_size=args.m)
                       
outname = args.i.split('.bed')[0]+'_split.bed' if args.o == None else args.o

outfile.to_csv(outname, sep='\t', header=False, index=False)
