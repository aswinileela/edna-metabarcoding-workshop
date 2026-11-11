# Run from the analysis working directory (the one containing table_180.qza and sample_metadata.txt)
#   Rscript Qiime2R-taxabarplot.R
library(qiime2R)
library(dplyr)
library(tibble)
library(purrr)
library(ggplot2)


# Get command-line arguments
args <- commandArgs(trailingOnly = TRUE)
meta_category <- "INDO_REGION"
metadata_file_path <- "sample_metadata.txt"
taxa_path <- "04_taxonomic_classification"

# Read metadata
metadata <- read_q2metadata(metadata_file_path)

# Read SVs and taxonomy
SVs <- read_qza("table_180.qza")$data 
taxonomy_file_path <- file.path(taxa_path, "taxonomy.qza")
if (!file.exists(taxonomy_file_path)) {
  stop("taxonomy.qza not found in the specified path.")
}
taxonomy <- read_qza(taxonomy_file_path)$data %>% parse_taxonomy()

# Summarize taxa
taxasums <- summarize_taxa(SVs, taxonomy)

# Taxonomic levels to consider
taxonomic_levels <- c("Species", "Genus", "Phylum", "Class", "Order", "Family")

# Create the output directory if it doesn't exist
output_directory <- "07_Taxonomy_Barplot_visualization"
dir.create(output_directory, showWarnings = FALSE)

# Loop through taxonomic levels
for (level in taxonomic_levels) {
  taxasums_level <- taxasums[[level]]
  pdf_filename <- file.path(output_directory, paste0(tools::toTitleCase(gsub("_", " ", level)), "_taxonomy.pdf"))
  
  # Create the plot
  taxa_barplot(taxasums_level, metadata, meta_category)
  
  # Save the plot as PDF
  ggsave(pdf_filename, height = 5, width = 13, device = "pdf")  # wide enough for the long legend labels
}
