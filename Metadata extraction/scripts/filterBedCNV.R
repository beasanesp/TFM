#!/usr/bin/env Rscript
# This script takes a bed annotation file as produced by IsoCNV;
# with columns 'chrom', 'start', 'end', 'variant', 'sample', 'log','cn'
# In theory it should work with any bed file, although you should change the 
# Column names where we call fread to import the bedfile. 
# Length to filter on is set by filter_len (50), but if you want to have control of this
# you can change it to args[4] and set the fitler length

pkgs <- c('data.table', 'dplyr', 'stringr', 'DescTools', 'rlang', 'parallel')
inst = lapply(pkgs, library, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments! [realCNV.bed] [output path] [Number of Processes]", call. = FALSE)
}

# Prototyping
# cnv.path <- "full_annot.bed"
# out.path =  './'
# n_cores = 48

cnv.path = args[1]
out.path = args[2]
n_cores = args[3]
filter_len = 50

# Print input name
inputname <- tail(str_split(cnv.path, '/')[[1]], 1)
cat("Analyzing", inputname , '\n')

# Make the output name
out_name_exc <- paste0(head(str_split(inputname, '.bed')[[1]],1), '_excluded.bed')
out_name_realcnv <- paste0(head(str_split(inputname, '.bed')[[1]],1), '_filtered.bed')

# Read in the data
cnvs <- fread(cnv.path, col.names=c('chrom', 'start', 'end', 'variant', 'sample', 'log', 'cn'))

# Save all regions less than 50 basepairs long, to be exported later
cnvs_filtered_len <- cnvs %>% mutate(length = end-start) %>% 
  filter(length < filter_len) %>% 
  select(-length) %>% mutate(reason = "length")
# Filter length >= 50
cnvs <- cnvs %>% mutate(length = end-start) %>% 
  filter(length >= filter_len) %>% 
  select(-length)

# create df with all possible combinations of chromosome/sample
all_combis <- expand.grid(unique(cnvs$chrom),unique(cnvs$sample))

# Function to detect overlapping regions.
# cnvdf = realCNV dataframe, with colnames = c('chrom', 'start', 'end', 'variant', 'sample', 'log','cn')
# chr = chromosome to subset for
# indiv = samplename to subset for
detectOverlap <- function(cnvdf, chr, indiv){
  # Subset for individual and chromosome
  ss <- cnvdf %>% filter(chrom == chr, sample == indiv)
  # If the dataframe is empty, return the empty dataframe
  if (is_empty(ss$chrom)) {
    return(ss)
  }
  # create column for overlapping regions
  ss$overlap <- NA
  # Iterate over the rows
  for (row in 1:nrow(ss)) {
    # Detect overlap
    overlap <- Overlap(c(ss[row,]$start, ss[row,]$end), ss[,2:3])
    # Overlap is detected with itself; set this to 0
    overlap[row] <- 0
    # Set any overlap to TRUE, no overlap to NA
    overlap <- fifelse(overlap==0, NA, T)
    # coalesce with the $overlap column.
    ss$overlap <- coalesce(ss$overlap, overlap)
  }
  # Return the dataframe with all the overlapping regions
  return(ss[!is.na(ss$overlap),-'overlap'])
}


# create forking cluster and assign data to them
cl <- makeCluster(n_cores, type = 'FORK')
clusterExport(cl, "cnvs")
clusterExport(cl, "all_combis")
clusterExport(cl, "detectOverlap")

# Perform main function
cnv_overlaps <- bind_rows(parApply(cl, all_combis, 1, function(xx){detectOverlap(cnvs, xx[1],xx[2])}))

realCNV <- rbind(cnvs, cnv_overlaps) %>%
  group_by_all() %>%
  filter(n() == 1)

cnv_overlaps$reason <- "duplicate"
cnv_excluded <- bind_rows(cnv_overlaps, cnvs_filtered_len)

# cnv_overlaps = dataframe with overlapping regions,
# cnv_excluded =  dataframe with all excluded regions, dropped by duplicate or length
# realCNV = dataframe with non-overlapping regions, no duplicate annotations

fwrite(cnv_excluded, file = out_name_exc, col.names = T, sep = '\t', row.names = F)
fwrite(realCNV, file = out_name_realcnv, col.names = T, sep = '\t', row.names = F)

cat('Filtered CNV annotations saved into:\t', out_name_realcnv, 
    '\nExluded regions are saved into:\t\t', out_name_exc, '\n',
    'A total of', nrow(cnv_excluded), 'annotations were excluded, of which', 
    round(nrow(cnvs_filtered_len)/nrow(cnv_excluded)*100, 1), '% due to their length and', 
    round(nrow(cnv_overlaps)/nrow(cnv_excluded)*100, 1), '% due to conflicting annotations \n ')

stopCluster(cl)



