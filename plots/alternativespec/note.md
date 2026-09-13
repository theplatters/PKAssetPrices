---
title: "Alternative specification: regenerated equilibrium panels"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [plots, PKAssetPrices, alternativespec, asset-model]
project: "PKAssetPrices working paper"
---

# Alternative specification — regenerated plots

These twelve files (six PDF + six PNG) are the equilibrium panels regenerated on
2026-09-13 from the **current working tree** of `src/static/models/asset_model.jl`
after two model-side changes:

## What changed in the model

1. **`c` is now clipped** (`asset_model.jl`, equation + IS/ADc curve blocks):
   `c == clamp(c0 - c1 * (credit_sd_channel * SD), 0.0, 1.0)`.
   The credit-rationing parameter is constrained to `[0, 1]`, matching the
   economic interpretation stated in the teaching note. Baseline behaviour is
   unchanged (`c = 0.8` sits inside the bounds).

2. **PQC scenario parameter change** (`s0 = 1.2` instead of the base `0.836`):
   higher autonomous speculative debt amplifies the credit-rationing
   crowding-out, so the risk indicator `psi = SD/dL` is now clearly higher in
   PQC than in Baseline — the increase the teaching-note TODO complained was
   too small to see in rounded output.

## Main equilibrium numbers (default `i0 = 0.01`)

| Scenario | AP | SD | Y | c | r | psi = SD/dL |
|---|---|---|---|---|---|---|
| Baseline | 0.9966 | 0.3887 | 6.566 | 0.8000 | 0.1120 | 0.1059 |
| PQC | 1.6321 | 0.6365 | 6.076 | 0.7363 | 0.1093 | **0.1732** |
| PQCr | 0.8700 | 0.3393 | 6.327 | 0.8000 | 0.1307 | 0.0969 |
| PQCrDIFF | 0.8143 | 0.3176 | 6.566 | 0.8000 | 0.1120 | 0.0882 |
| FirmsRation | 1.0258 | 0.4001 | 5.801 | 0.8000 | 0.1077 | 0.1212 |

Baseline `->` PQC gap in `psi`: **0.1059 -> 0.1732** (was ~0.006 at the old
`s0 = 0.836`).

## How these were produced

```{.bash}
julia --project=. scripts/produce_static_plots.jl
```

Run under Julia 1.12.7 with the active `Manifest.toml` (1.12.7). The working-tree
figures in `plots/` were overwritten; the versions captured here are the same
files, copied into this folder for comparison with the repository as it was
committed at HEAD.