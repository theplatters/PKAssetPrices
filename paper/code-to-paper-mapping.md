---
title: "Code-to-Paper Mapping: what PKAssetPrices contains vs. what the teaching note needs"
author: "Hermes (statistics profile)"
date: "2026-09-13"
tags: [mapping, reproducibility, teaching-note, PKAssetPrices]
project: "PKAssetPrices working paper"
---

This note answers step (1) of the working-paper readiness review: of the extensive
PKAssetPrices codebase, which parts are actually needed to build and reproduce the
static teaching note in `paper/teaching-note.tex`? It is a scope map, not a critique.

# Bottom line

The teaching note uses **one small, self-contained slice** of the repository: the
static linear asset-market model and the five canonical equilibrium plots. Everything
else in the repo (the Dash dashboard, the dynamic models, the optimisation experiments,
the Mathematica notebooks, the exploration notebooks) is infrastructure for *other*
projects or for interactive teaching and is **outside the scope** of the working paper.

# What the paper actually depends on

- `src/static/models/asset_model.jl` -- the canonical model. Defines `SimplePK`,
  `AssetModel` (= `Baseline`), and the four scenarios `PQC`, `PQCr`, `PQCrDIFF`,
  `FirmsRation`. All equations, parameters, and the `@curves` block that produces the
  IS/IR/AD/AS/AMD curves live here.
- `src/static/static_model.jl`, `src/static/model_macros.jl`,
  `src/static/balance_sheets.jl`, `src/static/helper_functions.jl` -- the `@model` /
  `@scenario` DSL and the `solve_model` / balance-sheet machinery that `asset_model.jl`
  is built on. These are loaded by the module; treat them as the model's runtime.
- `src/PKAssetPrices.jl` -- the module entry point (includes the above).
- `src/plotting/static_plotting.jl` -- generates the five `plots/*_equilibrium_panel.pdf`
  figures referenced by the paper: `baseline`, `pqc`, `pqcr`, `pqcrdiff`,
  `firmsration` (plus `simplepk` for the no-asset-market baseline figure).
- `scripts/produce_static_plots.jl` -- the reproducible entry point that regenerates
  those figures.
- `paper/tables/StockMatrix_*.tex`, `paper/tables/FlowMatrix_*.tex` -- the stock-flow
  matrices input by the paper (`\input{tables/...}`).
- `paper/ref.bib`, `paper/speculation-refs.bib` -- the bibliography.
- `paper/linear-model-changes-handout.tex` -- the author handout documenting how the
  linear model became canonical (useful provenance, not part of the paper build).

# Present in the repo but NOT needed for the static teaching note

- `src/dash/` and `src/dash.jl` -- the Dash web dashboard for interactive exploration.
  Pedagogically valuable, but the manuscript does not depend on it. If a companion
  "interactive tool" is advertised (the paper's footnote on p. 8 links to the Github
  repo), the dashboard is the thing being linked; it is optional for the WP text itself.
- `src/dynamic/` (`dynamic_model.jl`, `model_macros.jl`, `models/`) -- the discrete-time
  dynamic extensions (adaptive expectations, endogenised $\alpha$/$c$, hysteresis sketch).
  The conclusion of the note (teaching-note.tex:597-609) explicitly frames these as
  *future work* and states they are not used for the equilibrium figures. Keep out of
  WP scope unless the dynamic section is promoted from sketch to result.
- `src/optim/oscillatory_optim.jl` -- oscillatory-parameter search; research tooling.
- `src/static/models/end_alpha.jl`, `pc_model.jl`, `models/archive/` -- alternative /
  superseded model variants (the handout explains the linear model superseded the
  nonlinear one). Historical, not needed.
- `notebooks/` (`.ipynb`) and `*.nb` (Mathematica) -- interactive exploration and curve
  prototyping. Not part of the build; `pc_curves.nb` and `assetmarketplots*.nb` are large.
- `output/*.csv` -- cached equilibrium/risk outputs; regeneration comes from the model,
  not from these files.
- `test/` -- the Julia test suite (335 tests). Valuable for confidence but not a build
  input; the handout reports it passing.

# Suggested scope rule for the working paper

Treat `src/static` + `asset_model.jl` + `static_plotting.jl` + the five PDFs + the two
table files as the **reproducibility surface**. When the paper claims a number, it must
be reproducible from exactly those files with the pinned `Manifest.toml` (Julia 1.12).
Everything under `src/dash`, `src/dynamic`, `src/optim`, the notebooks, and the archives
is "project context" and should not be cited as producing any result in the note.
