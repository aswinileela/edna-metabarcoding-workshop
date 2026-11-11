#!/usr/bin/env python3
"""Quick static PCoA plot from a QIIME 2 *_pcoa_results.qza (same data as the Emperor plot).

Usage: plot_pcoa.py <pcoa_results.qza> <sample_metadata.txt> <column> <out.png> [title]
Needs pandas and matplotlib.
"""
import sys, zipfile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

qza, meta_path, column, out = sys.argv[1:5]
title = sys.argv[5] if len(sys.argv) > 5 else ""
with zipfile.ZipFile(qza) as z:
    name = next(n for n in z.namelist() if n.endswith("data/ordination.txt"))
    lines = z.read(name).decode().splitlines()
prop = [float(x) for x in lines[next(i for i, l in enumerate(lines) if l.startswith("Proportion explained")) + 1].split("\t")]
start = next(i for i, l in enumerate(lines) if l.startswith("Site\t")) + 1
rows = []
for l in lines[start:]:
    if not l.strip():
        break
    f = l.split("\t")
    rows.append((f[0], float(f[1]), float(f[2])))
pc = pd.DataFrame(rows, columns=["sample-id", "PC1", "PC2"]).set_index("sample-id")
meta = pd.read_csv(meta_path, sep="\t", comment="#", index_col=0)
meta.index.name = "sample-id"
pc = pc.join(meta)
fig, ax = plt.subplots(figsize=(5.5, 4.5))
for (grp, d), col in zip(pc.groupby(column), ["#d95f02", "#1b9e77", "#7570b3", "#e7298a"]):
    ax.scatter(d.PC1, d.PC2, s=70, label=grp, color=col, edgecolor="k")
    for sid, r in d.iterrows():
        ax.annotate(r["New_name"] if "New_name" in r else sid, (r.PC1, r.PC2), xytext=(4, 4), textcoords="offset points", fontsize=7)
ax.set_xlabel(f"PC1 ({prop[0]*100:.1f}%)")
ax.set_ylabel(f"PC2 ({prop[1]*100:.1f}%)")
ax.set_title(title)
ax.legend(title=column)
fig.tight_layout()
fig.savefig(out, dpi=130)
