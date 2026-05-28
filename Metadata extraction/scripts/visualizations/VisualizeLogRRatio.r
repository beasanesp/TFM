#!/usr/bin/env Rscript

# Script to visualize the computed log R ratio of a single metatable.
# Creates boxplots to represent the classes. The horizontal line is where LRR=0
# run as Rscript [metatable] [output directory]

library(dplyr)
library(ggplot2)
library(data.table)
library(tidyr)
library(tools)

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

# path_orignal_metatable <- './example/predictions/input/202202-4.meta'
# output_path <- "./"

colours <- c("#FFA400", "#CB0000", "#016FB9", "#C9D5B5", "#963484", '#ffcf00', '#01a39e')
# Load data
path_orignal_metatable <- args[1]
output_path <- args[2]

batchname <- basename(tools::file_path_sans_ext(path_orignal_metatable))

data <- fread(path_orignal_metatable)

p <- data %>% select(c('log', 'variant')) %>%
  mutate(variant = factor(variant, levels=c("NOR", "DEL", "DUP"))) %>%
  ggplot(., aes(x=variant, y=log, fill=variant)) +
  geom_boxplot()+
  scale_fill_manual(values = colours)+
  labs(title='Log R Ratio per variant',
       y = "Log R Ratio", x= "Copy Number") +
  theme_classic() +
  theme(axis.text.x = element_text(size = 10),
        axis.text.y = element_text(size = 15),
        axis.title.x = element_blank(),
        axis.title = element_text(size = 17.5, face = 'bold'),
        plot.title = element_text(hjust = 0.5, face = 'bold', size = 25),
        legend.position = c(0.9,0.1),
        legend.title = element_text(size=15, face='bold')) +
  geom_hline(yintercept = 0) +
  guides(fill=guide_legend(title="Variant"))

filename <- paste0(output_path,'/',batchname,'_LRR.png')

ggsave(
  filename,
  plot = p,
  device = "png",
  scale = 1,
  width = 1080,
  height = 1080,
  units = 'px',
  dpi = 150
)