#!/usr/bin/env Rscript

# Script to visualize the variant class distribution as piechart. Point to the directory with metatables
# (ideally the "input folder" that you also use for predictions)
# run as Rscript [directory that contains metatables] [output directory]

library(dplyr)
library(ggplot2)
library(data.table)
library(ggrepel)
library(scales)


args = commandArgs(trailingOnly=TRUE)
# Test arguments are supplied
if (length(args)==0){
  stop("Please provide arguments!", call. = FALSE)
}

#path_orignal_metadir <- './example/predictions/input/'
# output_path <- "./"

colours <- c("#FFA400", "#CB0000", "#016FB9", "#C9D5B5", "#963484", '#ffcf00', '#01a39e')
# Load data
path_orignal_metadir <- args[1]
output_path <- args[2]

files <- list.files(path_orignal_metadir, full.names = T)

for (f in 1:length(files)){
  batchname <- tools::file_path_sans_ext(list.files(path_orignal_metadir, full.names = F))[f]
  
  df <- fread(files[f], header=T)
  df$variant <- factor(df$variant, levels= c("NOR","DEL", "DUP"))
  
  data <- as.data.frame(table(df$variant))
  
  # Compute the position of labels
  data <- data %>% 
    arrange(desc(Var1)) %>%
    mutate(prop = Freq / sum(data$Freq) *100) %>%
    mutate(ypos = cumsum(prop)- 0.5*prop )
  
  
  p <- ggplot(data, aes(x="", y=prop, fill=Var1)) +
    geom_bar(stat="identity", width=1, color="black", size = 1.25) +
    coord_polar("y", start=0) +
    theme_void()+ 
    theme(legend.position="none") +
    geom_text(aes(y = ypos, label = Var1), color = "white", size=6) +
    scale_fill_manual(values = c(colours[1],colours[2],colours[3])) +
    geom_label_repel(data = data,
                     aes(y = ypos, label = percent(prop/100)),
                     size = 4.5, nudge_x = 1, show.legend = FALSE) +
    labs(title=paste0("Distribution of Variant classes\nFile ", batchname)) +
    theme(plot.title = element_text(size=24, face="bold", hjust = 0.5))
  
  filename <- paste0(output_path,'/',batchname,'_variant_distribution.png')
  
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
}

