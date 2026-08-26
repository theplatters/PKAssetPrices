using PKAssetPrices.Static: Baseline, FirmsRation, PQC, PQCr, PQCrDIFF,
  SimplePK, solve_model
using CairoMakie
using PKAssetPrices
using Printf


function print_equilibrium(name, solution)
  println("Model: $name")
  for (k, v) in sort(collect(solution.variables))
    @printf("  %12s = %.6f\n", k, v)
  end
  return
end

function save_figure(output_dir, stem, figure)
  pdf_path = joinpath(output_dir, "$(stem).pdf")
  save(pdf_path, figure; pt_per_unit=2)
  println("Saved static equilibrium panel to $pdf_path")

  png_path = joinpath(output_dir, "$(stem).png")
  save(png_path, figure)
  return println("Saved static equilibrium panel to $png_path")
end

function (@main)(ARGS)
  default_output_dir = normpath(joinpath(@__DIR__, "..", "plots"))
  output_dir = isempty(ARGS) ? default_output_dir : abspath(first(ARGS))
  mkpath(output_dir)

  simplepk_solution = solve_model(SimplePK)
  simplepk_figure = StaticPlotting.panel(simplepk_solution, StaticPlotting.StandardPanel())
  save_figure(output_dir, "simplepk_equilibrium_panel", simplepk_figure)
  print_equilibrium("SimplePK", simplepk_solution)

  baseline_solution = solve_model(Baseline)
  baseline_figure = StaticPlotting.panel(
    baseline_solution,
    StaticPlotting.AssetMarketPanel();
    reference_solution=nothing,
  )
  save_figure(output_dir, "baseline_equilibrium_panel", baseline_figure)
  print_equilibrium("Baseline", baseline_solution)

  asset_market_models = (
    ("pqc", PQC, 0.0),
    ("pqcr", PQCr, 0.0),
    ("pqcrdiff", PQCrDIFF, 0.0),
    ("firmsration", FirmsRation, 0.5),
  )
  for (name, model, i₀) in asset_market_models
    solution = solve_model(model)
    figure = StaticPlotting.panel(
      solution,
      StaticPlotting.AssetMarketPanel();
      reference_solution=baseline_solution,
      lower_i0_factor=i₀
    )
    save_figure(output_dir, "$(name)_equilibrium_panel", figure)
    print_equilibrium(name, solution)
  end

  return 0


end
