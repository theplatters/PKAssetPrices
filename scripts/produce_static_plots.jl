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

  # Notebook data-space positions are converted to relative-axis coordinates.
  baseline_label_positions = (
    is_ir = Dict(
      "IS" => (13/30, 8/9),
      "IR" => (11/12, 79/90),
      "IR (lower i₀)" => (53/60, 5/9),
    ),
    ad_as = Dict(
      "AD" => (0.2, 0.88),
      "AD (lower i₀)" => (0.4, 0.76),
      "AS" => (0.92, 0.8),
    ),
    asset_market = Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.03),
      "Demand (lower i₀)" => (0.87, 0.32),
    ),
  )
  baseline_solution = solve_model(Baseline)
  baseline_figure = StaticPlotting.panel(
    baseline_solution,
    StaticPlotting.AssetMarketPanel();
    reference_solution=nothing,
    is_ir_label_positions=baseline_label_positions.is_ir,
    ad_as_label_positions=baseline_label_positions.ad_as,
    asset_market_label_positions=baseline_label_positions.asset_market,
  )
  save_figure(output_dir, "baseline_equilibrium_panel", baseline_figure)
  print_equilibrium("Baseline", baseline_solution)

  shared_label_positions = (
    is_ir = Dict(
      "IS" => (13/30, 8/9),
      "IR" => (11/12, 79/90),
      "IR (lower i₀)" => (53/60, 5/9),
      "IS (base)" => (3/5, 1/6),
    ),
    ad_as = Dict(
      "AD" => (0.1, 0.88),
      "AD (lower i₀)" => (0.35, 0.45),
      "AS" => (0.92, 0.8),
      "AD (base)" => (19/30, 1/10),
    ),
    asset_market = Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.03),
      "Demand (lower i₀)" => (0.86, 0.35),
      "Demand (base)" => (9/70, 1/3),
    ),
  )

  # PQCrDIFF has no cited notebook, so it keeps default (empty) positions.
  default_label_positions = (is_ir = Dict(), ad_as = Dict(), asset_market = Dict())
  model_panel_specs = (
    ("pqc", PQC, 0.0, shared_label_positions),
    ("pqcr", PQCr, 0.0, shared_label_positions),
    ("pqcrdiff", PQCrDIFF, 0.0, default_label_positions),
    ("firmsration", FirmsRation, 0.5, shared_label_positions),
  )
  for (name, model, i₀, positions) in model_panel_specs
    solution = solve_model(model)
    figure = StaticPlotting.panel(
      solution,
      StaticPlotting.AssetMarketPanel();
      reference_solution=baseline_solution,
      lower_i0_factor=i₀,
      is_ir_label_positions=positions.is_ir,
      ad_as_label_positions=positions.ad_as,
      asset_market_label_positions=positions.asset_market,
    )
    save_figure(output_dir, "$(name)_equilibrium_panel", figure)
    print_equilibrium(name, solution)
  end

  return 0


end
