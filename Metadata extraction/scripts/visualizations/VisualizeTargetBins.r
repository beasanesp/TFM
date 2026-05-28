#!/usr/bin/env Rscript

# Script to visualize the target bins
# run as Rscript [original targets] [rebinned targets] [output directory]

library(dplyr)
library(ggplot2)

args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

# Load data
path_orignal_targets <- args[1]
path_rebinned_targets <- args[2]
output_path <- args[3]

df_targets <- read.table(path_orignal_targets)
df_rebin <- read.table(path_rebinned_targets)

df_filtered <- df_targets %>% 
  mutate(l=V3-V2, type = factor('Original zoomed', levels = c('Original','Original zoomed', 'Rebinned')) ) %>% 
  filter(l<=500) %>% select(-l)
  
  
df_targets$type <- factor("Original", levels = c('Original','Original zoomed', 'Rebinned'))
df_rebin$type <- factor("Rebinned", levels = c('Original','Original zoomed', 'Rebinned'))

df <- rbind(df_targets,df_filtered,df_rebin) %>%
  mutate(length = V3-V2)

p <- ggplot(df, aes(x=length)) +  
  geom_histogram(color="black", fill="white", bins=20) +
  geom_vline(aes(xintercept=median(length)),
             color="red", linetype="dashed", size=1) +
  facet_grid(~type, scales = 'free') +
  theme_classic() +
  labs(title="Distribution of Target sizes",
       x ="Size of bin (bp)", y = "Count") +
  theme(plot.title = element_text(size=24, face="bold", hjust = 0.5),
        axis.title.x = element_text(size=16),
        axis.title.y = element_text(size=16),
        axis.text = element_text(size = 12),
        strip.text.x = element_text(
          size = 14, face = "bold"
        ))
filename <- paste0(output_path,'/target_distribution.png')

ggsave(
  filename,
  plot = p,
  scale = 1,
  width = 1920,
  height = 810,
  units = 'px',
  dpi = 150
)


