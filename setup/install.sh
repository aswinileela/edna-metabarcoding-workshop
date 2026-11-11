#!/usr/bin/env bash
# One-shot installer for the workshop software (Linux x86_64, also works on WSL2).
#
#   bash setup/install.sh                 # QIIME 2 + FastQC env, and R env
#   bash setup/install.sh --qiime         # only the QIIME 2 env
#   bash setup/install.sh --r             # only the R env (Module 07)
#   bash setup/install.sh --miniforge     # also install Miniforge (conda) first if conda is missing
#
# Creates two conda environments:
#   edna-qiime2   QIIME 2 amplicon 2024.10 (Cutadapt, DADA2, MAFFT, FastTree, ANCOM-BC) + FastQC
#   edna-r        R + qiime2R, dplyr, tibble, purrr, ggplot2
# Needs ~10 GB disk and an internet connection. Takes 10-30 minutes.
set -euo pipefail

QIIME_VERSION=${QIIME_VERSION:-2024.10}
QIIME_YML="https://data.qiime2.org/distro/amplicon/qiime2-amplicon-${QIIME_VERSION}-py310-linux-conda.yml"
QIIME_ENV=${QIIME_ENV:-edna-qiime2}
R_ENV=${R_ENV:-edna-r}

DO_QIIME=0; DO_R=0; DO_MINIFORGE=0
for a in "$@"; do
  case $a in
    --qiime) DO_QIIME=1 ;;
    --r) DO_R=1 ;;
    --miniforge) DO_MINIFORGE=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 1 ;;
  esac
done
[ $DO_QIIME -eq 0 ] && [ $DO_R -eq 0 ] && { DO_QIIME=1; DO_R=1; }

[ "$(uname -s)" = "Linux" ] || { echo "This script supports Linux/WSL2. On macOS see https://docs.qiime2.org/"; exit 1; }
say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

if ! command -v conda >/dev/null; then
  if [ $DO_MINIFORGE -eq 1 ]; then
    say "Installing Miniforge to \$HOME/miniforge3"
    curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$(uname -m).sh"
    bash /tmp/miniforge.sh -b -p "$HOME/miniforge3"
    "$HOME/miniforge3/bin/conda" init bash >/dev/null
    export PATH="$HOME/miniforge3/bin:$PATH"
  else
    echo "conda not found. Re-run with --miniforge to install it, or install Miniconda/Miniforge yourself."
    exit 1
  fi
fi
CONDA=$(command -v mamba || command -v conda)
# Strict channel priority (set in some users' ~/.condarc) makes the QIIME 2 environment unsolvable.
export CONDA_CHANNEL_PRIORITY=flexible

env_exists() { conda env list | awk '{print $1}' | grep -qx "$1"; }

if [ $DO_QIIME -eq 1 ]; then
  if env_exists "$QIIME_ENV"; then
    say "Env $QIIME_ENV already exists - skipping (remove it with: conda env remove -n $QIIME_ENV)"
  else
    say "Creating $QIIME_ENV (QIIME 2 amplicon $QIIME_VERSION)"
    TMP=$(mktemp -d); curl -fsSL -o "$TMP/qiime2.yml" "$QIIME_YML"
    $CONDA env create -n "$QIIME_ENV" --file "$TMP/qiime2.yml" -y
    say "Adding FastQC to $QIIME_ENV"
    $CONDA install -n "$QIIME_ENV" -c conda-forge -c bioconda fastqc -y
  fi
fi

if [ $DO_R -eq 1 ]; then
  if env_exists "$R_ENV"; then
    say "Env $R_ENV already exists - skipping"
  else
    say "Creating $R_ENV (R + plotting packages)"
    # qiime2R needs several Bioconductor packages; take them prebuilt from bioconda instead of compiling.
    $CONDA create -n "$R_ENV" -c conda-forge -c bioconda -y r-base r-remotes r-dplyr r-tibble r-purrr \
      r-ggplot2 r-yaml r-data.table r-tidyr r-ape r-matrix r-dt r-hmisc r-zcompositions \
      bioconductor-biostrings bioconductor-rhdf5 bioconductor-phyloseq bioconductor-s4vectors \
      bioconductor-treesummarizedexperiment
    say "Installing qiime2R from GitHub"
    conda run -n "$R_ENV" --no-capture-output Rscript -e \
      'options(repos = c(CRAN = "https://cloud.r-project.org")); remotes::install_github("jbisanz/qiime2R", upgrade = "never"); stopifnot(requireNamespace("qiime2R", quietly = TRUE))'
  fi
fi

say "Checking installs"
[ $DO_QIIME -eq 1 ] && { conda run -n "$QIIME_ENV" qiime --version; conda run -n "$QIIME_ENV" fastqc --version; }
[ $DO_R -eq 1 ] && conda run -n "$R_ENV" Rscript -e 'library(qiime2R); library(ggplot2); cat("qiime2R OK\n")'
cat <<MSG

Done. Use the environments with:
  conda activate $QIIME_ENV     # Modules 02-06
  conda activate $R_ENV         # Module 07
MSG
