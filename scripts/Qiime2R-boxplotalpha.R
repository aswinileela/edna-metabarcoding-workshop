# Run from the analysis working directory (the one containing sample_metadata.txt and 03_core-metrics-results/)
#   Rscript Qiime2R-boxplotalpha.R
library(qiime2R)
library(dplyr)
library(tibble)
library(purrr)
library(ggplot2)

# File paths are relative to the analysis working directory
metadata_file_path <- "sample_metadata.txt"
alpha_metrics_path <- "03_core-metrics-results"
x_axis_label <- "INDO_REGION"   #column to compare

# Load data
metadata <- read_q2metadata(metadata_file_path)
alpha_metrics <- c("shannon_vector.qza", "observed_features_vector.qza", "faith_pd_vector.qza", "evenness_vector.qza")

# Load alpha diversity metrics and merge with metadata
alpha_data <- lapply(alpha_metrics, function(metric) {
  data <- read_qza(file.path(alpha_metrics_path, metric))
  data$data %>% rownames_to_column("SampleID")
})


alpha_data <- reduce(alpha_data, left_join, by = "SampleID")
metadata <- metadata %>% left_join(alpha_data, by = "SampleID")

# Define metric variables based on column names
metric_variables <- c("shannon_entropy", "observed_features", "faith_pd", "pielou_evenness")

# Create directory to save the PDF files
output_dir <- "06_alpha_boxplot_visualize"
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

# Create and save box plots
metrics_labels <- c("Shannon Entropy", "Observed Features", "Faith's PD", "Evenness")
for (i in seq_along(metric_variables)) {
  metric <- metric_variables[i]
  label <- metrics_labels[i]
  plot_title <- sprintf("Boxplots for %s", label)
  
  # Modify x-axis label for labs
  modified_x_label <- gsub("_", " ", x_axis_label)
  modified_x_label <- tools::toTitleCase(modified_x_label)
  
  pdf_filename <- file.path(output_dir, sprintf("Boxplot_of_%s_by_%s.pdf", gsub(" ", "_", tolower(label)), gsub(" ", "_", tolower(x_axis_label))))
  
  p <- ggplot(metadata, aes(x = !!sym(x_axis_label), y = !!sym(metric))) +
    geom_boxplot(fill = "lightblue", color = "black", alpha = 0.8, na.rm = TRUE) +
    labs(x = modified_x_label, y = label) +
    ggtitle(plot_title) +
    theme_bw()
  
  ggsave(pdf_filename, plot = p, height = 3, width = 4, device = "pdf") # save a PDF 3 inches by 4 inches
}

# End of script
