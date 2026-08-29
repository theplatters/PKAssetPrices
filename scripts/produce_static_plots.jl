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


  # Notebook data-space positions are converted to relative-axis coordinates.
  baseline_label_positions = (
    is_ir=Dict(
      "IS" => (9 / 30, 8 / 9),
      "IR" => (10 / 12, 79 / 90),
      "IR (lower i₀)" => (53 / 60, 5 / 9),
    ),
    ad_as=Dict(
      "AD" => (0.2, 0.88),
      "AD (lower i₀)" => (0.42, 0.76),
      "AS" => (0.92, 0.70),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.08),
      "Demand (lower i₀)" => (0.74, 0.32),
    ),
  )

  simplepk_solution = solve_model(SimplePK)
  simplepk_figure = StaticPlotting.panel(simplepk_solution, StaticPlotting.StandardPanel(),
    is_ir_label_positions=baseline_label_positions.is_ir,
    ad_as_label_positions=baseline_label_positions.ad_as,
    asset_market_label_positions=baseline_label_positions.asset_market,
  )
  save_figure(output_dir, "simplepk_equilibrium_panel", simplepk_figure)
  print_equilibrium("SimplePK", simplepk_solution)

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

  pqc_label_positions = (
    is_ir=Dict(
      "IS" => (8 / 30, 8 / 9),
      "IR" => (10 / 12, 79 / 90),
      "IR (lower i₀)" => (53 / 60, 5 / 9),
      "IS (base)" => (0.55, 1 / 6),
    ),
    ad_as=Dict(
      "AD" => (0.2, 0.88),
      "AD (lower i₀)" => (0.42, 0.76),
      "AS" => (0.92, 0.70),
      "AD (base)" => (17 / 30, 1 / 10),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.08),
      "Demand (lower i₀)" => (0.74, 0.32),
      "Demand (base)" => (1 / 70, 0.42),
    ),
  )
  pqcr_label_positions = (
    is_ir=Dict(
      "IS" => (8 / 30, 8 / 9),
      "IR" => (20 / 24, 82 / 90),
      "IR (lower i₀)" => (53 / 60, 54 / 90),
      "IS (base)" => (0.54, 1 / 6),
    ),
    ad_as=Dict(
      "AD" => (0.18, 0.88),
      "AD (lower i₀)" => (0.42, 0.76),
      "AS" => (0.92, 0.70),
      "AD (base)" => (17 / 30, 1 / 10),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.08),
      "Demand (lower i₀)" => (0.72, 0.32),
      "Demand (base)" => (1 / 70, 0.82),
    ),
  )
  firmsration_label_positions = (
    is_ir=Dict(
      "IS" => (0.22, 8 / 9),
      "IR" => (10 / 12, 85 / 100),
      "IR (lower i₀)" => (53 / 60, 60 / 100),
      "IS (base)" => (0.55, 1 / 6),
    ),
    ad_as=Dict(
      "AD" => (0.12, 0.88),
      "AD (lower i₀)" => (0.1, 0.7),
      "AS" => (0.9, 0.85),
      "AD (base)" => (17 / 30, 1 / 10),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.5, 0.1),
      "Asset Supply" => (0.22, 0.1),
      "Demand (lower i₀)" => (0.72, 0.35),
      "Demand (base)" => (1 / 70, 0.42),
    ),
  )

  pqcrdiff_label_positions = (
    is_ir=Dict(
      "IS" => (0.25, 8 / 9),
      "IR" => (10 / 12, 85 / 100),
      "IR (lower i₀)" => (53 / 60, 65 / 100),
      "IS (base)" => (0.55, 1 / 6),
    ),
    ad_as=Dict(
      "AD" => (0.15, 0.88),
      "AD (lower i₀)" => (0.1, 0.7),
      "AS" => (0.9, 0.85),
      "AD (base)" => (17 / 30, 1 / 10),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.45, 0.12),
      "Asset Supply" => (0.27, 0.1),
      "Demand (lower i₀)" => (0.72, 0.35),
      "Demand (base)" => (-100, 0.42),
    ),
  )

  # PQCrDIFF has no cited notebook, so it keeps default (empty) positions.
  model_panel_specs = (
    ("pqc", PQC, 0.0, pqc_label_positions),
    ("pqcr", PQCr, 0.0, pqcr_label_positions),
    ("firmsration", FirmsRation, 0.8, firmsration_label_positions),
    ("pqcrdiff", PQCrDIFF, 0.0, pqcrdiff_label_positions),
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