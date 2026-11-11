# Module 00: Setup

You need a Linux computer (or Windows with WSL2), about 10 GB of disk space and an internet connection. Everything below is copy-and-paste.

## 1. Get the materials

```bash
git clone <this-repository-url> edna-metabarcoding-workshop
cd edna-metabarcoding-workshop
```

## 2. Install the software

One script creates two conda environments:

| Environment | Contains | Used in |
|---|---|---|
| `edna-qiime2` | QIIME 2 amplicon 2024.10 (Cutadapt, DADA2, MAFFT, FastTree, ANCOM-BC) and FastQC | Modules 02-06 |
| `edna-r` | R, qiime2R, dplyr, tibble, purrr, ggplot2 | Module 07 |

```bash
bash setup/install.sh
```

If you do not have conda yet, let the script install Miniforge for you, then open a new terminal:

```bash
bash setup/install.sh --miniforge
```

Only one environment: `bash setup/install.sh --qiime` or `bash setup/install.sh --r`.

Check that it worked:

```bash
conda activate edna-qiime2
qiime --version
fastqc --version
```

Expected: `q2cli version 2024.10.1` and a FastQC version number.

## 3. Prepare a working folder

Run every later command from one `analysis/` folder so the file names in the modules match.

```bash
mkdir analysis && cd analysis
cp -r ../data/raw_fastq ../data/12S_database ../data/sample_metadata.txt .
ls raw_fastq | wc -l
head -3 sample_metadata.txt
```

Expected: `16`, then the header and `#q2:types` rows of the metadata table.

## 4. Check the input files

The FASTQ files follow the Casava 1.8 naming pattern QIIME 2 expects:

```
POOL-ELAS-6596-2_S107_L001_R1_001.fastq.gz
POOL-ELAS-6596-2_S107_L001_R2_001.fastq.gz
```

`sample_metadata.txt` is tab-separated. The first column is the sample ID (the FASTQ prefix). The `#q2:types` row declares column types.

| sample-id | New_name | Site | Bio_rep | INDO_REGION |
|---|---|---|---|---|
| #q2:types | categorical | categorical | categorical | categorical |
| POOL-ELAS-6596-2 | SB_01_1 | BENTENG | A | ACEH |
| POOL-ELAS-6596-3 | SB_01_2 | BENTENG | B | ACEH |
| POOL-ELAS-6596-5 | SB_02_1 | JABOI | A | ACEH |
| POOL-ELAS-6596-6 | SB_02_2 | JABOI | B | ACEH |
| POOL-ELAS-0132-14 | BM_1 | BATU_MERAH | A | LEMBEH_STRAIT |
| POOL-ELAS-0132-15 | BM_2 | BATU_MERAH | B | LEMBEH_STRAIT |
| POOL-ELAS-6596-29 | TK_1 | TELUK_KEMBAHU | A | LEMBEH_STRAIT |
| POOL-ELAS-6596-30 | TK_2 | TELUK_KEMBAHU | B | LEMBEH_STRAIT |

## Short on time? Run everything at once

From the repository root (not inside `analysis/`), with `edna-qiime2` active:

```bash
bash scripts/run_workflow.sh -t 8        # -t = number of CPU threads
```

This runs Modules 02-06 and writes the same folder layout as `example_results/`. Use the modules below to understand each step, and compare your outputs with the pictures.

[![Next](../../docs/images/next_button.svg)](../01_linux_basics/) &nbsp; **[Module 01: Linux basics](../01_linux_basics/)**