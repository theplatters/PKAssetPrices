using PKAssetPrices.Static: Baseline, PQC, PQCr, PQCrDIFF, SimplePK, solve_model
using CairoMakie
using PKAssetPrices


function (@main)(ARGS)
  default_output_dir = normpath(joinpath(@__DIR__, "..", "plots"))
  output_dir = isempty(ARGS) ? default_output_dir : abspath(first(ARGS))
  mkpath(output_dir)

  baseline = StaticPlotting.panel(solve_model(SimplePK))
  baseline_path = joinpath(output_dir, "simplepk_equilibrium_panel.pdf")
  save(baseline_path, baseline)
  println("Saved static equilibrium panel to $baseline_path")

  asset_market_models = (
    ("baseline", Baseline),
    ("pqc", PQC),
    ("pqcr", PQCr),
    ("pqcrdiff", PQCrDIFF),
  )
  for (name, model) in asset_market_models
    solution = solve_model(model)
    figure = StaticPlotting.panel(
      solution,
      StaticPlotting.AssetMarketPanel(),
    )
    output_path = joinpath(output_dir, "$(name)_equilibrium_panel.pdf")
    save(output_path, figure)
    println("Saved static equilibrium panel to $output_path")
  end

  return 0


end
