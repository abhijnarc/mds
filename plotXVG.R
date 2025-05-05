# Load required packages
library(Peptides)

args <- commandArgs(trailingOnly=TRUE)
input_file <- args[1]
output_file <- args[2]
plot_title <- args[3]

# Read and plot using plotXvg()
png(output_file)
plotXvg(input_file, main = plot_title)
dev.off()