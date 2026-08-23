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
| Balance-sheet assets | Blue `RGBf(0.20, 0.59, 0.86)` |
| Balance-sheet liabilities | Red `RGBf(0.84, 0.25, 0.30)` |

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

## Key differences from `static_plotting.jl`

| Aspect | `static_plotting.jl` | This script |
|--------|----------------------|-------------|
| Color | royalblue / crimson | purple / orange |
| Panel titles | "Goods market and interest-rate rule" | "(A) Goods Market Dynamics" |
| Interest ticks | linear | percentage labels (6%, 8%, …) |
| Layout | 1×2 top + full-width bottom | strict 2×2 grid |
| Frame style | default | black frame, gridlines |