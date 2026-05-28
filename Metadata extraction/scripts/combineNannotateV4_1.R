#!/usr/bin/env Rscript
# Commandline-friendly R-script for combining & parsing the metadatatable. 
# V1: Working script
# V2: Adjusted the parsing of the repeatmasker information. Instead
#     of giving numbers of each type of repeat found, it converts
#     into whether the region contains a repeat yes/no
# V2.1: added the trimming and imputation, instead of in MetaTrimmR.r 
# V3 adapted for the isoCNV pipeline
# V3.1 Adjusted the CNV annotation
##################################################################
##                         Dependencies                         ##
##################################################################
library(stringr, quietly = T, warn.conflicts = F)
library(data.table, quietly = T, warn.conflicts = F)
library(plyr, warn.conflicts = F, quietly = T)
library(dplyr, quietly = T, warn.conflicts = F)
library(DescTools, quietly = T, warn.conflicts = F)
library(tidyr, warn.conflicts = F, quietly = T)
library(tibble, warn.conflicts = F, quietly = T)
library(data.table)



#################################################################
##                      Commandline parse                      ##
#################################################################
args <- commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

VSF.path <- args[1]
GC.path <- args[2]
CNV.path <- args[3]
DEPTH.path <- args[4]
RM.path <- args[5]
OUT.path <- args[6]

# TEMP for prototyping (23456789909169_1)
# VSF.path <- '/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/vsf/23456789912610_1_final_annotation.hg19_multianno.vcf.parsed'
# GC.path <- '/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/gc/GC_pertargets.tsv'
# CNV.path <- '/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/realCNV_202208-5.bed'
# DEPTH.path <- '/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/depths/23456789912610_1.depth.norm'
# RM.path <- '/media/sequentia/synology_office/Ruben/3.GetMetadata/3.Metatables/6.isoCNV/202208-5/rm/subset.hg19.bed'
# OUT.path <- './'

inputname <-  paste0(str_remove(tail(str_split(DEPTH.path, "/")[[1]], n=1), pattern = '.depths.norm'),'_recaled')

#################################################################
##                   Constructing metatable                    ##
#################################################################
print(paste('Constructing metatable for', inputname))

# Load in data
VSF <- fread(VSF.path, header = T)
GC <- fread(GC.path, sep='\t', col.names = c("chrom", "start", "end", "gene", "gc.perc"), skip=1, header = F)
DEPTH <- fread(DEPTH.path, sep = '\t', fill=T)
CNV <- fread(CNV.path, col.names = c('chrom', 'start', 'end', 'variant', 'sample', 'cn'))

setDT(GC)
setDT(VSF)
setDT(DEPTH)

# Eliminar duplicados antes de la unión
GC_unique <- unique(GC, by = c("chrom", "start", "end"))
VSF_unique <- unique(VSF, by = c("chrom", "start", "end"))
DEPTH_unique <- unique(DEPTH, by = c("chrom", "start", "end"))

# Ahora realiza la unión con los dataframes únicos
gc_vsf <- merge(GC_unique, VSF_unique, by = "chrom", all.x = TRUE, suffixes = c(".gc", ".vsf"))
gc_vsf <- gc_vsf[abs(start.gc - start.vsf) <= 5 & abs(end.gc - end.vsf) <= 5]

gc_vsf_depth <- merge(gc_vsf, DEPTH_unique, by = "chrom", all.x = TRUE)
gc_vsf_depth <- gc_vsf_depth[abs(start.gc - start) <= 5 & abs(end.gc - end) <= 5]


# Armar metatable con columnas seleccionadas
metatable <- gc_vsf_depth[, .(
  chrom,
  start = start,           # O usar i.start si querés la versión de VSF o DEPTH
  end = end,
  gene,
  gc.perc,
  n.hetero,
  n.homo,
  baf.mean,
  baf.sd,
  doc,
  doc.sd
)]

# Add region length
metatable <- metatable %>%
  mutate(length = as.integer(end) - as.integer(start))
#################################################################
##            Annotate with Copy Number information            ##
#################################################################

print(paste('Annotating metatable for', inputname))
metatable$sample <- inputname

cnv.subset <- CNV %>% filter(sample == inputname)

# Create CN column and use NA values as placeholder
metatable$variant <- as.character(NA)
metatable$cn <- as.character(NA)

if (!empty(cnv.subset)){
  # For-loop to annotate the metatable with CN information
  for (i in 1:nrow(cnv.subset)) {
    # based on assumption start-end are in column 2-3
    tmp <- na_if(Overlap(metatable[metatable$chrom==cnv.subset[i,]$chrom,2:3], c(cnv.subset[i,]$start, cnv.subset[i,]$end)), 0)
    tmp_cn <- tmp
    tmp[!is.na(tmp)] <- cnv.subset[i,]$variant
    tmp_cn[!is.na(tmp_cn)] <- as.character(cnv.subset[i,]$cn)
    
    metatable[metatable$chrom==cnv.subset[i,]$chrom,]$variant <- coalesce(metatable[metatable$chrom==cnv.subset[i,]$chrom,]$variant, tmp)
    metatable[metatable$chrom==cnv.subset[i,]$chrom,]$cn <- coalesce(metatable[metatable$chrom==cnv.subset[i,]$chrom,]$cn, tmp_cn)
  }
}

# Classify unannotated regions as "Normal"
metatable$variant[is.na(metatable$variant)] <- 'NOR'
# Copy number normal state (diploid) , 1 for deletion of one allele, 0 for homozygotic deletion. Then, 3 a duplication, and so on
metatable$cn[is.na(metatable$cn)] <- 2
metatable$CN <- str_replace_all(metatable$CN, 'DEL', '1')
metatable$CN <- str_replace_all(metatable$CN, 'DUP', '2')

#################################################################
##           Annotate with RepeatMasker information            ##
#################################################################

RM <- read.table(RM.path, header = F, colClasses = c('character', 'integer', 'integer',
                                                     rep('NULL', 4), 'character',  'NULL'),
                 col.names = c('CHROM', 'START', 'END','x','xx','xxx','GENE', 'REPEAT', 'OVERLAP'))

RM <- RM %>% unite(c(CHROM,START,END), col='region') %>% 
  separate(., REPEAT, into = c('class', 'family'), sep='/', 
           fill = 'right') %>% select(region, class)

TRM <-  table(RM)
TRM <- as.data.frame.matrix(TRM)

TRM$repeatmasked <- rowSums(TRM)
TRM[TRM$repeatmasked > 0,] <- 1

TRM <- tibble::rownames_to_column(TRM, "region")
TRM <-  TRM %>% select(c('region', 'repeatmasked'))


metatable <- metatable %>% unite(c(chrom,start,end), col='region')

# Combine to a final table:
metatable <- left_join(metatable, TRM, by="region")
metatable$repeatmasked[is.na(metatable$repeatmasked)] <- 0
# empty col to later store log data
metatable$log <- NA

# Impute doc.sd missing values with 0
metatable$doc.sd[is.na(metatable$doc.sd)] <- 0

# Split the "region" column, and reorder other columns.
metatable <- metatable %>% separate(region, into=c('chrom','start','end')) %>%
  select('sample', 'chrom', 'start', 'end', 'gene', 'length', 'gc.perc', 
         'repeatmasked', 'n.hetero', 'n.homo', 'baf.mean', 'baf.sd', 
         'doc', 'doc.sd', 'log', 'variant', 'cn')


#################################################################
##                           Output                            ##
#################################################################
# Save table to file
outfile = paste(OUT.path, inputname, sep='')
outname = paste(outfile, "meta", sep=".")
fwrite(metatable, file=outname, row.names = F, sep = "\t", quote = FALSE )
print(paste("Wrote file into", paste(outname, sep='')))
