#!/usr/bin/env Rscript
library(dplyr, quietly = TRUE, warn.conflicts = FALSE)
library(data.table, quietly = TRUE, warn.conflicts = FALSE)
library(stringr, quietly = TRUE, warn.conflicts = FALSE)
library(parallel, quietly = TRUE, warn.conflicts = FALSE)

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments! [Depthsfile] [Targets.bed] [Number of Processes] [Output path]", call. = FALSE)
}

# Funciones de normalización
normalizeCPM <- function(coverages){
  return(coverages / sum(coverages) * 1e6)
}

normalizeMeanNormalization <- function(coverages){
  return(coverages / mean(coverages, na.rm = TRUE))
}

normalizeMeanStandardization <- function(coverages){
  return((coverages - mean(coverages, na.rm = TRUE)) / sd(coverages, na.rm = TRUE))
}

meanNormalizeAndShift <- function(coverages){
  depth.mn <- normalizeMeanNormalization(coverages)
  return(depth.mn + abs(min(depth.mn, na.rm = TRUE)) + 1)
}

#Cargar datos
path_depths <- args[1]
path_targets <- args[2]

cat("Analizando", tail(str_split(path_depths, '/')[[1]], 1), '\n')

# Nombre de salida
outputname <- paste0(tail(str_split(path_depths, '/')[[1]], 1), '.norm')

# Leer archivos
targets <- fread(path_targets, col.names = c('chrom', 'start', 'end', 'gene'))
depths <- fread(path_depths, select = c(1, 2, 3), col.names = c("REF", "POS", "COV"))

# Cromosomas únicos
chroms <- unique(targets$chrom)

# Inicializar lista de resultados
result_list <- list()

# Número de núcleos
numCores <- args[3]

# Procesar por cromosoma
for (chr in chroms) {
  cat("Procesando", chr, "\n")
  
  targets_chr <- targets[chrom == chr]
  depths_chr <- depths[REF == chr]
  depths_chr$mn <- meanNormalizeAndShift(depths_chr$COV)
  
  # Crear clúster
  cl <- makeCluster(numCores, type = "FORK")
  
  # Exportar objetos y funciones necesarias
  clusterExport(cl, varlist = c("targets_chr", "depths_chr"), envir = environment())
  clusterEvalQ(cl, {
    library(data.table)
  })
  
  # Función paralela para cada región
  op_chr <- parLapply(cl, seq_len(nrow(targets_chr)), function(i) {
    region <- targets_chr[i, ]
    sub <- depths_chr[POS >= region$start & POS <= region$end]
    data.table(
      chrom = region$chrom,
      start = region$start,
      end = region$end,
      gene = region$gene,
      doc = mean(sub$mn, na.rm = TRUE),
      doc.sd = sd(sub$mn, na.rm = TRUE)
    )
  })
  
  # Detener clúster
  stopCluster(cl)
  
  # Consolidar resultados
  result_chr <- rbindlist(op_chr)
  result_chr$doc[is.na(result_chr$doc)] <- 1
  result_list[[chr]] <- result_chr
}

# Combinar resultados
final_output <- rbindlist(result_list)

# Guardar salida
pathOut <- paste0(args[4], outputname)
fwrite(final_output, pathOut, sep = '\t')
cat("File saved in ", pathOut)
