#!/usr/bin/env Rscript

# Script to compute the confusion matrix and classification report.
# !!!!! ONLY WORKS WITH BINARY CLASSIFICATION !!!!!!
# run as Rscript [metatable with predictions] [output directory]

library(dplyr)
library(ggplot2)
library(data.table)
library(tidyr)
library(tools)
library(stringr)
library(cvms)
library(tibble)

cr <- function(cm, dp=2) {
  ct <- sum(cm)
  cs <- colSums(cm)
  rs <- rowSums(cm)
  tp <- diag(cm)
  tn <- ct - (rs + cs - tp)
  fp <- rs - tp
  fn <- cs - tp
  pr <- tp / (tp + fp)
  re <- tp / (tp + fn)
  f1 <- 2 * pr * re / (pr + re)
  ac <- sum(tp) / ct
  list(summary=round(data.frame(tp, tn, fp, fn, precision=pr, recall=re, f1_score=f1, support=cs), dp),
       accuracy=round(ac, dp),
       support=ct)
}

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

# path_orignal_predictiontable <- './example/predictions/output/predictions/202202-4.meta.pred'
# output_path <- "./"

# Load data
path_orignal_predictiontable <- args[1]
output_path <- args[2]

batchname <- basename(tools::file_path_sans_ext(path_orignal_predictiontable))

data <- fread(path_orignal_predictiontable)

d_binomial <- data %>%
  mutate(target = ifelse(variant == "NOR", 0, 1),
         prediction = ifelse(predictions == "NOR", 0, 1)) %>%
  select(c("target", "prediction"))


basic_table <- table(d_binomial)
cfm <- as_tibble(basic_table)
p <- plot_confusion_matrix(cfm, 
                      target_col = "target", 
                      prediction_col = "prediction",
                      counts_col = "n",
                      add_sums = F,
                      place_x_axis_above = FALSE,
                      palette = "Greens")

filename <- paste0(output_path,'/',batchname,'_Confusion_matrix.png')

ggsave(
  filename,
  plot = p,
  device = "png",
  scale = 1,
  width = 1080,
  height = 1080,
  units = 'px',
  dpi = 300
)

filename <- paste0(output_path,'/',batchname,'_classificationReport.csv')
tmp <- as.data.frame(cr(basic_table))
colnames(tmp) <- str_remove_all(colnames(tmp), "summary.")
write.csv(tmp, file=filename, row.names = F)

