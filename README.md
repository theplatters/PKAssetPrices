# PKAssetPrices

Julia code for reproducing the static Post-Keynesian asset-price models,
equilibrium results, and figures. All equations, default parameters, and scenario
definitions are in `src/static/models/asset_model.jl`.

## Requirements

- Julia 1.12 (tested with 1.12.6).
- GNU Make and Git.

## Reproduce figures and results

Run from the repository root:

```sh
make setup      # Install packages and the local public-push guard.
make            # Regenerate every figure as PDF and PNG in plots/.
make test       # Check equilibrium residuals, calibration, curves, and plotting.
```

The scripts also print each model's equilibrium variables to the terminal.
Capture them with `make > results.log` if desired. Generated figures are ignored
by Git and are rebuilt from source on every invocation.

| Paper figure | Model / scenario | Output stem in `plots/` |
| --- | --- | --- |
| 1 | `SimplePK`: goods and credit markets | `simplepk_equilibrium_panel` |
| 2 | `Baseline` / `AssetModel`: add the asset market | `baseline_equilibrium_panel` |
| 3 | `PQC`: speculative debt affects credit rationing | `pqc_equilibrium_panel` |
| 4 | `PQCr`: policy responds to asset prices | `pqcr_equilibrium_panel` |
| 5 | `FirmsRation`: asset prices affect firms' investment | `firmsration_equilibrium_panel` |
| 6 | `PQCrDIFF`: a separate speculative borrowing rate | `pqcrdiff_equilibrium_panel` |

`make equilibrium` generates those six panels. `make experiments` generates six
additional baseline comparison panels: reinvestment share `γ` at 0.2, 0.6, and 0.8,
and autonomous speculative debt `s0` at 0.5, 0.8, and 1.2. Their stems are
`baseline_gamma_{low,medium,high}_panel` and
`baseline_s0_{low,medium,high}_panel`. Each stem produces both `.pdf` and `.png`,
for 24 files in total. The experiments compare each parameter setting with the
baseline; equilibrium panels also show the lower-policy-rate counterfactual.

To change the output directory or Julia executable:

```sh
make OUTPUT_DIR=/tmp/pkassetprices-figures JULIA=/path/to/julia
```

Without Make, run the equivalent Julia commands:

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
julia --startup-file=no --project=. scripts/produce_static_plots.jl
julia --startup-file=no --project=. scripts/produce_gamma_experiments_plots.jl
julia --startup-file=no --project=. test/runtests.jl
```

To inspect a solution directly:

```julia
using PKAssetPrices
solution = solve_model(Static.Baseline)
solution.variables                  # All equilibrium variables.
Static.eval_curve(solution)         # Curves evaluated at equilibrium.
Static.display_sheets(solution)     # Sector balance sheets.
```
