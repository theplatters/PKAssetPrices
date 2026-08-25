---
title: "Mathematica-Style Equilibrium Panel Generator"
tags: [documentation, plotting, mathematica-style]
---

Produces a 2×2 composite figure for the **Baseline** model that matches the
visual style of `graphtest-money.nb`.

## Files

| File | Description |
|------|-------------|
| `scripts/produce_mathematica_style_panel.jl` | Standalone Julia script |
| `notebooks/MathematicaStyleBaseline.ipynb` | Jupyter notebook (same logic) |

## Colour scheme (from Mathematica)

| Element | Colour |
|---------|--------|
| IS curve, AD curve, Asset Demand | Purple `RGBf(0.5, 0, 0.5)` |
| IR curve, AS curve, Asset Supply | Orange `RGBf(1, 0.5, 0)` |
| Counterfactual curves (lower i₀) | Faded purple, dashed |
| Balance-sheet assets | Purple `RGBf(0.5, 0, 0.5)` (same palette as IS/AD) |
| Balance-sheet liabilities | Orange `RGBf(1, 0.5, 0)` (same palette as IR/AS) |
| Reference/base overlays (`static_plotting` `reference_solution`) | Grey `RGBf(0.45, 0.45, 0.45)` |

## Subplot layout

```{.text}
┌─────────────────────┬─────────────────────┐
│ (A) Goods Market    │ (B) Output and      │
│      Dynamics       │      Inflation      │
│      (IS/IR)        │      Dynamics (AD/AS)│
├─────────────────────┼─────────────────────┤
│ (C) Financial       │ Sector Balance      │
│      Market         │      Sheets         │
│      Dynamics       │ (stacked bar chart) │
└─────────────────────┴─────────────────────┘
```

## Usage

### From the terminal

```bash
cd PKAssetPrices
julia --project=. scripts/produce_mathematica_style_panel.jl
```

Output: `plots/baseline_mathematica_style.pdf` and `.png`.

### From VSCode / Jupyter

Open `notebooks/MathematicaStyleBaseline.ipynb` and run all cells. Output
appears inline; the last cell exports the PDF/PNG.

## Relationship to `static_plotting.jl`

| Aspect | `static_plotting.jl` | This script |
|--------|----------------------|-------------|
| Color | purple / orange | purple / orange |
| Scope | Reusable standard and asset-market panels | Standalone Baseline panel |
| Reference curves | Optional grey Baseline overlays | None (plots Baseline itself) |
| Layout | Standard or strict 2×2 asset-market layout | Strict 2×2 grid |

Both `static_plotting.jl` and this script use the same purple/orange palette:
IS, AD and Asset Demand use purple (`RGBf(0.5, 0, 0.5)`), while IR, AS and
Asset Supply use orange (`RGBf(1, 0.5, 0)`). The balance-sheet bars also use
purple for assets and orange for liabilities (not blue/red).

## `produce_static_plots.jl`

Renders one equilibrium panel per model and exports both a PDF and a PNG for
each, printing the sorted equilibrium variables to the console.

| File | Description |
|------|-------------|
| `scripts/produce_static_plots.jl` | Standalone Julia script generating per-model panels |

### Reference overlays

`SimplePK` uses `StandardPanel`, which has no reference-overlay keyword.
`Baseline` uses `AssetMarketPanel` with `reference_solution = nothing`. The four
scenario asset-market models — `PQC`, `PQCr`, `PQCrDIFF`, and `FirmsRation` —
pass `reference_solution = baseline_solution`, so each receives the grey
Baseline reference layers (including `PQCrDIFF`).

### Outputs

- Six models are exported, producing **six PDF and six PNG** files with the
  stems `simplepk_equilibrium_panel`, `baseline_equilibrium_panel`,
  `pqc_equilibrium_panel`, `pqcr_equilibrium_panel`, `pqcrdiff_equilibrium_panel`,
  and `firmsration_equilibrium_panel`.
- PDFs are saved with `pt_per_unit = 2`; PNGs use the default unit scaling.
- Equilibrium reporting prints the model's `variables` **sorted by name**.

### Usage

```bash
cd PKAssetPrices
julia --project=. scripts/produce_static_plots.jl [output_dir]
```

The optional `output_dir` argument defaults to `plots/`.
