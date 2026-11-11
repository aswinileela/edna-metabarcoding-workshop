#!/usr/bin/env bash
# Run the complete workshop workflow (Modules 02-06) in one go.
#
#   conda activate edna-qiime2          # see setup/install.sh
#   bash scripts/run_workflow.sh                 # all steps, output in ./analysis
#   bash scripts/run_workflow.sh -t 4 -o my_run  # 4 threads, custom output folder
#   bash scripts/run_workflow.sh denoise taxonomy  # only some steps (in order)
#
# Steps: import trim denoise diversity taxonomy ancombc
# Each step needs the outputs of the earlier ones.
set -euo pipefail

THREADS=$(( $(nproc) < 8 ? $(nproc) : 8 ))
OUT=analysis
while getopts "t:o:h" opt; do
  case $opt in
    t) THREADS=$OPTARG ;;
    o) OUT=$OPTARG ;;
    *) sed -n '2,11p' "$0"; exit 0 ;;
  esac
done
shift $((OPTIND - 1))
STEPS=("$@"); [ ${#STEPS[@]} -eq 0 ] && STEPS=(import trim denoise diversity taxonomy ancombc)

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v qiime >/dev/null || { echo "qiime not found. Run: conda activate edna-qiime2"; exit 1; }

mkdir -p "$OUT"
[ -d "$OUT/raw_fastq" ]          || cp -r "$REPO/data/raw_fastq" "$OUT/"
[ -d "$OUT/12S_database" ]       || cp -r "$REPO/data/12S_database" "$OUT/"
[ -f "$OUT/sample_metadata.txt" ] || cp "$REPO/data/sample_metadata.txt" "$OUT/"
cd "$OUT"

FWD=GTCGGTAAAACTCGTGCCAGC                 # MiFish-U-F
REV=CATAGTGGGGTATCTAATCCCAGTTTG           # MiFish-U-R
DEPTH=45000                               # rarefaction / sampling depth
say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step_import() {
  say "Module 02: import reads"
  qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path raw_fastq --input-format CasavaOneEightSingleLanePerSampleDirFmt \
    --output-path paired-end-demux.qza
  qiime demux summarize --i-data paired-end-demux.qza --o-visualization paired-end-demux.qzv
}

step_trim() {
  say "Module 02: trim MiFish primers with Cutadapt"
  qiime cutadapt trim-paired --i-demultiplexed-sequences paired-end-demux.qza \
    --p-front-f $FWD --p-front-r $REV --p-error-rate 0.1 --p-overlap 12 \
    --p-discard-untrimmed --p-cores "$THREADS" --o-trimmed-sequences trimmed.qza
  qiime demux summarize --i-data trimmed.qza --o-visualization trimmed.qzv
}

# denoise_run <input.qza> <suffix> <trunc-len>   -> table<suffix>.qza etc.
denoise_run() {
  local in=$1 sfx=$2 trunc=$3
  qiime dada2 denoise-paired --i-demultiplexed-seqs "$in" \
    --p-trim-left-f 0 --p-trim-left-r 0 --p-trunc-len-f "$trunc" --p-trunc-len-r "$trunc" \
    --p-n-threads "$THREADS" --o-table "table$sfx.qza" \
    --o-representative-sequences "rep-seqs$sfx.qza" --o-denoising-stats "denoising-stats$sfx.qza"
  qiime metadata tabulate --m-input-file "denoising-stats$sfx.qza" \
    --o-visualization "01_denoising_clustering_summary/denoising-stats$sfx.qzv"
  qiime feature-table summarize --i-table "table$sfx.qza" \
    --o-visualization "01_denoising_clustering_summary/table$sfx.qzv" \
    --m-sample-metadata-file sample_metadata.txt
  qiime feature-table tabulate-seqs --i-data "rep-seqs$sfx.qza" \
    --o-visualization "01_denoising_clustering_summary/rep-seqs$sfx.qzv"
}

step_denoise() {
  mkdir -p 01_denoising_clustering_summary
  say "Module 03: DADA2, primer-trimmed, no truncation"; denoise_run trimmed.qza "" 0
  say "Module 03: DADA2, WITHOUT primer removal (comparison)"; denoise_run paired-end-demux.qza _ori 0
  say "Module 03: DADA2, primer-trimmed, truncate at 180 bp (used downstream)"; denoise_run trimmed.qza _180 180
}

step_diversity() {
  say "Module 04: phylogeny"
  qiime phylogeny align-to-tree-mafft-fasttree --i-sequences rep-seqs_180.qza \
    --p-n-threads "$THREADS" --output-dir 02_phylogenetic_analysis
  say "Module 04: core metrics (depth $DEPTH) and rarefaction"
  qiime diversity core-metrics-phylogenetic --i-phylogeny 02_phylogenetic_analysis/rooted_tree.qza \
    --i-table table_180.qza --p-sampling-depth $DEPTH --m-metadata-file sample_metadata.txt \
    --p-n-jobs-or-threads "$THREADS" --output-dir 03_core-metrics-results
  qiime diversity alpha-rarefaction --i-table table_180.qza \
    --i-phylogeny 02_phylogenetic_analysis/rooted_tree.qza --p-max-depth $DEPTH \
    --m-metadata-file sample_metadata.txt \
    --o-visualization 03_core-metrics-results/alpha-rarefaction_$DEPTH.qzv
  say "Module 04: alpha diversity significance (Kruskal-Wallis)"
  for m in faith_pd evenness shannon observed_features; do
    qiime diversity alpha-group-significance \
      --i-alpha-diversity 03_core-metrics-results/${m}_vector.qza \
      --m-metadata-file sample_metadata.txt \
      --o-visualization 03_core-metrics-results/${m//_/-}-group-significance.qzv
  done
  say "Module 04: beta diversity significance (PERMANOVA)"
  for m in unweighted_unifrac weighted_unifrac bray_curtis jaccard; do
    qiime diversity beta-group-significance \
      --i-distance-matrix 03_core-metrics-results/${m}_distance_matrix.qza \
      --m-metadata-file sample_metadata.txt --m-metadata-column INDO_REGION --p-pairwise \
      --o-visualization 03_core-metrics-results/${m//_/-}-region-significance.qzv
  done
}

step_taxonomy() {
  say "Module 05: classify ASVs against the Mitohelper 12S database"
  mkdir -p 04_taxonomic_classification
  classify() {
    qiime feature-classifier classify-consensus-blast --i-query rep-seqs_180.qza \
      --i-reference-reads "$1" --i-reference-taxonomy "$2" \
      --p-perc-identity 0.97 --p-query-cov 0.95 --p-maxaccepts 100 --p-min-consensus 0.8 \
      --p-num-threads "$THREADS" \
      --o-classification 04_taxonomic_classification/taxonomy.qza \
      --o-search-results 04_taxonomic_classification/taxonomy-search-results.qza
  }
  if ! classify 12S_database/12S-seqs-derep-uniq.qza 12S_database/12S-tax-derep-uniq.qza; then
    echo "Database was built with a different QIIME 2 release; re-importing it (Module 05, step 1)."
    unzip -p 12S_database/12S-seqs-derep-uniq.qza '*/data/dna-sequences.fasta' > 12S_database/reference-sequences.fasta
    unzip -p 12S_database/12S-tax-derep-uniq.qza '*/data/taxonomy.tsv' > 12S_database/reference-taxonomy.tsv
    qiime tools import --type 'FeatureData[Sequence]' --input-path 12S_database/reference-sequences.fasta \
      --input-format DNAFASTAFormat --output-path reference-sequences.qza
    qiime tools import --type 'FeatureData[Taxonomy]' --input-path 12S_database/reference-taxonomy.tsv \
      --input-format TSVTaxonomyFormat --output-path reference-taxonomy.qza
    classify reference-sequences.qza reference-taxonomy.qza
  fi
  qiime metadata tabulate --m-input-file 04_taxonomic_classification/taxonomy.qza \
    --o-visualization 04_taxonomic_classification/taxonomy.qzv
  qiime taxa barplot --i-table table_180.qza --i-taxonomy 04_taxonomic_classification/taxonomy.qza \
    --m-metadata-file sample_metadata.txt \
    --o-visualization 04_taxonomic_classification/taxa-bar-plots.qzv
}

step_ancombc() {
  say "Module 06: ANCOM-BC differential abundance (genus level)"
  mkdir -p 05_ancom_result
  qiime taxa collapse --i-table table_180.qza --i-taxonomy 04_taxonomic_classification/taxonomy.qza \
    --p-level 6 --o-collapsed-table 05_ancom_result/collapsed-taxonomy-table-level6.qza
  qiime composition ancombc --i-table 05_ancom_result/collapsed-taxonomy-table-level6.qza \
    --m-metadata-file sample_metadata.txt --p-formula "INDO_REGION" \
    --o-differentials 05_ancom_result/differential.qza
  qiime composition tabulate --i-data 05_ancom_result/differential.qza \
    --o-visualization 05_ancom_result/ancombc-region-table.qzv
  qiime composition da-barplot --i-data 05_ancom_result/differential.qza \
    --p-significance-threshold 0.05 --o-visualization 05_ancom_result/ancombc-region-barplot.qzv
}

for s in "${STEPS[@]}"; do
  declare -F "step_$s" >/dev/null || { echo "Unknown step: $s"; exit 1; }
  "step_$s"
done
say "Done. Results are in: $(pwd)"
echo "Open .qzv files at https://view.qiime2.org/ . For the R plots (Module 07): see modules/07_qiime2r_visualisation/"
