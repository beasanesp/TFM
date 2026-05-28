#!/usr/bin/env Rscript
library(runner,quietly = T, warn.conflicts = F)
library(data.table,quietly = T, warn.conflicts = F)
library(dplyr,quietly = T, warn.conflicts = F)
library(stringr,quietly = T, warn.conflicts = F)

###################################################################
randomUnderSampling <- function(dataframe, target){
  require(dplyr)
  majorityclass <- dataframe %>% 
    select(as.name(target)) %>%
    table() %>%
    as.data.frame() %>%
    slice(which.max(Freq)) %>%
    pull(var = 1) %>%
    as.character()
  tosample <- nrow(dataframe[dataframe[[target]]!=majorityclass,])
  
  return(
    rbind(dataframe[dataframe[[target]]==majorityclass,][sample(tosample)], 
          dataframe[dataframe[[target]]!=majorityclass,])
  )
}

computeLRR <- function(Robserved, Rexpected){
  return(log2(Robserved/Rexpected))
}

computeReference <- function(depthofcoverage, windowsize=25){
  require(runner)
  return(runner(depthofcoverage, k=windowsize, f = function(xi) {
    median(xi, na.rm = TRUE, trim = 0.05)}))
}

orderPriorCR <- function(dataframe){
  return(dataframe[
    with(dataframe, order(gc.perc, repeatmasked, length, baf.mean)),
  ])
}
###################################################################
args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

# Temp for prototyping
# path_metatable <- "/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/testBatches/tb3-1.meta"
# path_metatable <- 'P202106-3-ss.meta'
# path_output <- "/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/metatables/"
# path_output <- "./"

# Load data
path_metatable <- args[1]
path_output <- args[2]



# Print input name
name_input <- tail(str_split(tools::file_path_sans_ext(path_metatable), '/')[[1]], 1)
cat("Analyzing", name_input)

# Make the output name
outputname <- paste0(name_input, '.meta')

# Read data
mt <- fread(path_metatable, header = T, sep = '\t')

# TEMP FOR PROTOTYPING!!!!!!!!!
# mt <- orderPriorCR(mt)
# mt$logUnbalanced <- computeLRR(mt$doc, computeReference(mt$doc, windowsize = 25))
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Randomly undersample the data
mt.ss <- randomUnderSampling(mt, 'variant')
# sort the data
mt.ss <- orderPriorCR(mt.ss) 
# Compute log r ratio 
mt.ss$log <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 25))
# mt.ss$logBalanced <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 25))
# mt.ss$log5 <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 5))
# mt.ss$log10 <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 10))
# mt.ss$log50 <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 50))
# mt.ss$log100 <- computeLRR(mt.ss$doc, computeReference(mt.ss$doc, windowsize = 100))
# Write output
mt.ss <- cbind(batch = name_input, mt.ss)
pathOut <- paste0(path_output, outputname)
fwrite(mt.ss, pathOut, sep = '\t')








