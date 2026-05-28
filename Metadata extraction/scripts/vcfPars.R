rm(list = ls())
library(dplyr, quietly = T, warn.conflicts = F)
library(vcfR, quietly = T, warn.conflicts = F)
library(parallel, quietly = T, warn.conflicts = F)
library(data.table, quietly = T, warn.conflicts = F)
library(stringr, quietly = T, warn.conflicts = F)

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

# Function to compute variant data per region
hetHomo <- function(chrom, start, end, gene, variantdf){
  return(variantdf %>% filter(CHROM == chrom, 
                              between(POS, start, end)) %>%
           summarize(chrom = chrom,
                     start = start,
                     end = end,
                     gene = gene,
                     n.hetero=sum(zygosity=='hetero'),
                     n.homo=sum(zygosity=='homo'),
                     baf.mean = mean(baf, na.rm=T),
                     baf.sd = sd(baf, na.rm=T)))
}

path_vcf <- args[1]
path_targets <- args[2]
path_output <- args[3]
n_cores <- args[4]

# Print sample
cat("Analyzing", tail(str_split(path_vcf, '/')[[1]], 1))
outputname <- paste0(tail(str_split(path_vcf, '/')[[1]], 1), '.parsed')

# Read in data
vcf <- read.vcfR(path_vcf)
# Extract genotype data
gt <- extract.gt(vcf)
# Determine heterozygosity yes/no
hets <- is_het(gt, na_is_false = TRUE)
colnames(hets) <- c("zygosity")
# Compute BAF
ad <- extract.gt(vcf, element = "AD")
freqs <- AD_frequency(ad)
colnames(freqs) <- c("baf")

# Extract chrom, pos and ID
ss <-  as.data.frame(vcf@fix) %>% select(CHROM, POS,ID)
# Combine data, translate zygosity data
pvcf <- cbind(ss, hets, freqs)
rownames(pvcf) <- 1:nrow(pvcf)
pvcf$zygosity <- ifelse(pvcf$zygosity == TRUE, "hetero", "homo")

# Read in targets 
targets = fread(path_targets, col.names = c('chrom', 'start', 'end', 'gene'))

# 
numCores <- n_cores

# create forking cluster and assign data to them
cl <- makeCluster(numCores, type = 'FORK')
clusterExport(cl, "pvcf")
clusterExport(cl, "targets")
clusterExport(cl, "hetHomo")

# Perform main function
op <- bind_rows(parApply(cl, targets, 1, function(xx){hetHomo(xx[1],xx[2],xx[3], xx[4], pvcf)}))
op[is.na(op)] <- 0

# Write output
pathOut <- paste0(path_output, outputname)

fwrite(op, pathOut, sep = '\t')

stopCluster(cl)




