using PKAssetPrices.Static: Baseline, BaselineLinar, FirmsRation, FirmsRationLinar,
  PQC, PQCLinar, PQCr, PQCrLinar, PQCrDIFF, PQCrDIFFLinar, SimplePK, solve_model
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
    ("firmsration", FirmsRation),
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

  linar_asset_market_models = (
    ("baseline", BaselineLinar),
    ("pqc", PQCLinar),
    ("pqcr", PQCrLinar),
    ("pqcrdiff", PQCrDIFFLinar),
    ("firmsration", FirmsRationLinar),
  )
  for (name, model) in linar_asset_market_models
    solution = solve_model(model)
    figure = StaticPlotting.panel(
      solution,
      StaticPlotting.AssetMarketPanel();
      title="Static equilibrium overview — linear speculative-debt variant",
    )
    output_path = joinpath(output_dir, "$(name)_linar_equilibrium_panel.pdf")
    save(output_path, figure)
    println("Saved linear static equilibrium panel to $output_path")
  end

  return 0


end
