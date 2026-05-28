#!/usr/bin/env Rscript
library(dplyr,quietly = T, warn.conflicts = F)
library(data.table,quietly = T, warn.conflicts = F)
library(parallel,quietly = T, warn.conflicts = F)
library(stringr,quietly = T, warn.conflicts = F)

# library(tictoc)
#rm(list=ls()) 
# tic("Normalization script") # Start timing for prototyping

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments! [Depthsfile] [Targets.bed] [Number of Processes] [Output path]", call. = FALSE)
}

normalizeCPM <- function(coverages){
  return(coverages/sum(coverages)*(10^6))
}

normalizeMeanNormalization <- function(coverages){
  return(coverages/mean(coverages, na.rm = T))
}

normalizeMeanStandardization <- function(coverages){
  return((coverages-mean(coverages, na.rm = T))/sd(coverages, na.rm = T))
}

normalizeAll <- function(coverages){
  return(data.frame(
    "cpm" = normalizeCPM(coverages),
    "mn" = normalizeMeanNormalization(coverages),
    "ms" = normalizeMeanStandardization(coverages)
  ))  
}

meanNormalizeAndShift <- function(coverages){
  depth.mn <- normalizeMeanNormalization(coverages)
  return((depth.mn+abs(min(depth.mn))+1))
}

computeDocRegion <- function(chrom, start, end, gene, depthsdf){
  require(dplyr)
  return(depthsdf %>% 
           filter(REF == chrom,
                  between(POS, start, end)) %>%
           summarise('chrom' = chrom,
                     'start' = start,
                     'end' = end,
                     'gene' = gene,
                     # 'doc'= mean(COV, na.rm = T),
                     # 'doc.sd' = sd(COV, na.rm = T),
                     # 'doc.cpm'= mean(cpm, na.rm = T),
                     # 'doc.sd.cpm' = sd(cpm, na.rm = T),
                     'doc'= mean(mn, na.rm = T),
                     'doc.sd' = sd(mn, na.rm = T)#,
                     # 'doc.ms'= mean(ms, na.rm = T),
                     # 'doc.sd.ms' = sd(ms, na.rm = T)
           )
         
  )
}


# Load data
#path_depths <- args[1]
#path_targets <- args[2]

# Temporary path assignment for prototyping
 path_depths <-  "/media/sequentia/sdb1/visitor2/Run_DeVCopy_V2/NimbleGen/depths/SRR1301256_1.depths"
 path_targets <-  "/media/sequentia/sdb1/visitor2/Run_DeVCopy_V2/NimbleGen/Nimblegen_EZ_Exome_v2_annotated_sorted.bed"

 # Print input name
cat("Analyzing", tail(str_split(path_depths, '/')[[1]], 1), '\n')

# Make the output name
outputname <- paste0(tail(str_split(path_depths, '/')[[1]], 1), '.norm')

# Load data
targets <-  fread(path_targets, col.names = c('chrom', 'start', 'end', 'gene'))
depths <- fread(path_depths, colClasses = c('character', 'integer', 'integer', rep("NULL", 7)))

# mean normalize the data
depths$mn <-  meanNormalizeAndShift(depths$COV)

#numCores <- detectCores() # uncomment for maximum number of cores
numCores <- 5 # for prototyping
numCores <- args[3]

# create forking cluster and assign data to them
cl <- makeCluster(numCores, type = 'FORK')
clusterExport(cl, "depths")
clusterExport(cl, "targets")
clusterExport(cl, "computeDocRegion")

# Perform main function
op <- bind_rows(parApply(cl, targets, 1, function(xx){computeDocRegion(xx[1],xx[2],xx[3],xx[4], depths)}))
# impute regions without reads with 1; avoid zero
op$doc[is.na(op$doc)] <- 1

# Write output
pathOut <- paste0(args[4], outputname)
cat("File saved in ", pathOut)

fwrite(op, pathOut, sep = '\t')

stopCluster(cl)

# toc() # Stop timing for prototyping


