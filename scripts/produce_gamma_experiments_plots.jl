using PKAssetPrices.Static: Baseline, solve_model
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
  println("Saved parameter experiment panel to $pdf_path")

  png_path = joinpath(output_dir, "$(stem).png")
  save(png_path, figure)
  return println("Saved parameter experiment panel to $png_path")
end

"""Return a Baseline parametrization with parameter `key` overridden."""
function with_param(baseline, key, value)
  params = copy(baseline.params)
  params[key] = Float64(value)
  return PKAssetPrices.Static.Parametrization(
    baseline.model,
    params,
    copy(baseline.u0),
  )
end

"""Return a Baseline parametrization with `γ` overridden."""
function with_gamma(baseline, gamma_value)
  return with_param(baseline, :γ, gamma_value)
end

"""Return a Baseline parametrization with `s0` overridden."""
function with_s0(baseline, s0_value)
  return with_param(baseline, :s0, s0_value)
end

"""Build IS-IR specs without the lower-i₀ counterfactual.

`sol` is the parameter variant (colored), `reference_solution` is the
baseline (grey). Both IS and IR are shown for each parametrization so
any goods-market effect of the varied parameter remains visible.
"""
function experiment_is_ir_specs(sol, reference_solution, labels)
  return StaticPlotting.build_plot_specs(
    StaticPlotting.IS_IR_X_LIMITS,
    StaticPlotting.IS_IR_Y_LIMITS;
    labels,
    linewidth = 3,
    linestyle = :solid,
  ) do builder
    StaticPlotting.x_curve!(builder, "IS", :IS, :r, sol; color = StaticPlotting.IR_COLOR)
    StaticPlotting.y_curve!(builder, "IR", :IR, :Y, sol; color = StaticPlotting.IS_COLOR)
    StaticPlotting.x_curve!(
      builder, "IS (base)", :IS, :r, reference_solution;
      color = StaticPlotting.REFERENCE_COLOR, linewidth = 2.5,
    )
    StaticPlotting.y_curve!(
      builder, "IR (base)", :IR, :Y, reference_solution;
      color = StaticPlotting.REFERENCE_COLOR, linewidth = 2.5,
    )
  end
end

"""Build AD-AS specs without the lower-i₀ counterfactual."""
function experiment_ad_as_specs(sol, reference_solution, labels, x_limits)
  return StaticPlotting.build_plot_specs(
    x_limits,
    StaticPlotting.AD_AS_Y_LIMITS;
    labels,
    linewidth = 3,
    linestyle = :solid,
  ) do builder
    StaticPlotting.x_curve!(builder, "AD", :ADc, :P, sol; color = StaticPlotting.IS_COLOR)
    StaticPlotting.y_curve!(builder, "AS", :ASc, :Y, sol; color = StaticPlotting.IR_COLOR)
    StaticPlotting.x_curve!(
      builder, "AD (base)", :ADc, :P, reference_solution;
      color = StaticPlotting.REFERENCE_COLOR, linewidth = 2.5,
    )
  end
end

"""Build asset-market specs without the lower-i₀ counterfactual."""
function experiment_asset_specs(sol, reference_solution, labels, x_limits, y_limits)
  return StaticPlotting.build_plot_specs(
    x_limits,
    y_limits;
    labels,
    linewidth = 3,
    linestyle = :solid,
  ) do builder
    StaticPlotting.x_curve!(
      builder, "Asset Demand", :AMD, :AP, sol; color = StaticPlotting.IS_COLOR,
    )
    StaticPlotting.x_curve!(
      builder, "Asset Supply", :AMS, :AP, sol; color = StaticPlotting.IR_COLOR,
    )
    StaticPlotting.x_curve!(
      builder, "Asset Demand\n(base)", :AMD, :AP, reference_solution;
      color = StaticPlotting.REFERENCE_COLOR, linewidth = 2.5,
    )
  end
end

"""Asset-market limits covering both the variant and baseline equilibria."""
function experiment_asset_limits(sol, reference_solution)
  standard_x = StaticPlotting.ASSET_X_LIMITS
  standard_y = StaticPlotting.ASSET_Y_LIMITS
  ap_values = Float64[sol.variables[:AP], reference_solution.variables[:AP]]
  q_values = Float64[
    StaticPlotting.calculate_curve_path(sol, :AMD, :AP, ap_values[1:1])[1],
    StaticPlotting.calculate_curve_path(
      reference_solution, :AMD, :AP, ap_values[2:2],
    )[1],
  ]
  # Fall back to the equilibrium demand evaluation used by the library.
  # `calculate_curve_path` above evaluates AMD at the equilibrium AP, which
  # equals the fixed asset supply; keep the library helper for clarity.
  if all(first(standard_x) .<= q_values .<= last(standard_x)) &&
     all(first(standard_y) .<= ap_values .<= last(standard_y))
    return standard_x, standard_y
  end
  x_lo = minimum(q_values)
  x_hi = maximum(q_values)
  y_lo = minimum(ap_values)
  y_hi = maximum(ap_values)
  x_limits = extrema((0.5 * x_lo, 2.0 * x_hi))
  y_limits = extrema((0.5 * y_lo, 2.0 * y_hi))
  return x_limits, y_limits
end

"""Panel contrasting one parameter variant against the baseline (no i₀ curves)."""
function experiment_panel(
    sol,
    reference_solution;
    is_ir_label_positions=Dict(),
    ad_as_label_positions=Dict(),
    asset_market_label_positions=Dict(),
  )
  figure = Figure(
    size = (1400, 1000),
    fontsize = StaticPlotting.FIGURE_FONT_SIZE,
    figure_padding = (28, 38, 28, 28),
    backgroundcolor = :white,
  )
  is_ir_axis = Axis(
    figure[1, 1];
    title = rich("(A) ", "Goods Market Dynamics"; font = :bold),
    xlabel = "Output Y",
    ylabel = "interest rate r",
    xgridcolor = (:black, 0.12),
    ygridcolor = (:black, 0.12),
    titlesize = StaticPlotting.AXIS_TITLE_SIZE,
    xlabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    ylabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
  )
  ad_as_axis = Axis(
    figure[1, 2];
    title = rich("(B) ", "Output and Inflation Dynamics"; font = :bold),
    xlabel = "Output Y",
    ylabel = "Price Level P",
    xgridcolor = (:black, 0.12),
    ygridcolor = (:black, 0.12),
    titlesize = StaticPlotting.AXIS_TITLE_SIZE,
    xlabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    ylabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
  )
  asset_axis = Axis(
    figure[2, 1];
    title = rich("(C) ", "Financial Market Dynamics"; font = :bold),
    xlabel = "Quantity of assets traded",
    ylabel = "Asset Price AP",
    xgridcolor = (:black, 0.12),
    ygridcolor = (:black, 0.12),
    titlesize = StaticPlotting.AXIS_TITLE_SIZE,
    xlabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    ylabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
  )
  balance_axis = Axis(
    figure[2, 2];
    title = rich("(D) ", "Changes in Balance Sheets"; font = :bold),
    ylabel = "Amount",
    xgridvisible = false,
    ygridcolor = (:black, 0.08),
    titlesize = StaticPlotting.AXIS_TITLE_SIZE,
    xlabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    ylabelsize = StaticPlotting.AXIS_LABEL_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
    xticklabelsize = StaticPlotting.BALANCE_TICK_LABEL_SIZE,
  )

  is_ir_labels = StaticPlotting.reposition_labels(
    StaticPlotting.STANDARD_IS_IR_LABELS, is_ir_label_positions,
  )
  ad_as_labels = StaticPlotting.reposition_labels(
    StaticPlotting.STANDARD_AD_AS_LABELS, ad_as_label_positions,
  )
  asset_labels = StaticPlotting.reposition_labels(
    StaticPlotting.STANDARD_ASSET_MARKET_LABELS, asset_market_label_positions,
  )

  StaticPlotting.plot_specs!(
    is_ir_axis, experiment_is_ir_specs(sol, reference_solution, is_ir_labels),
  )

  ad_as_x_limits = StaticPlotting.AD_AS_X_LIMITS
  equilibrium_output = sol.variables[:Y]
  if !(first(ad_as_x_limits) <= equilibrium_output <= last(ad_as_x_limits))
    padding = 0.25
    ad_as_x_limits = (
      min(first(StaticPlotting.AD_AS_X_LIMITS), equilibrium_output - padding),
      max(last(StaticPlotting.AD_AS_X_LIMITS), equilibrium_output + padding),
    )
  end
  StaticPlotting.plot_specs!(
    ad_as_axis,
    experiment_ad_as_specs(sol, reference_solution, ad_as_labels, ad_as_x_limits),
  )

  asset_x_limits, asset_y_limits = experiment_asset_limits(sol, reference_solution)
  StaticPlotting.plot_specs!(
    asset_axis,
    experiment_asset_specs(
      sol, reference_solution, asset_labels, asset_x_limits, asset_y_limits,
    ),
  )

  StaticPlotting.plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 1, Relative(0.48))
  rowsize!(figure.layout, 2, Relative(0.52))
  return figure
end

# Backwards-compatible aliases for the earlier γ-only version of this script.
const gamma_is_ir_specs = experiment_is_ir_specs
const gamma_ad_as_specs = experiment_ad_as_specs
const gamma_asset_specs = experiment_asset_specs
const gamma_asset_limits = experiment_asset_limits
const gamma_panel = experiment_panel

function (@main)(ARGS)
  default_output_dir = normpath(joinpath(@__DIR__, "..", "plots"))
  output_dir = isempty(ARGS) ? default_output_dir : abspath(first(ARGS))
  mkpath(output_dir)

  # Baseline γ is 0.5 and baseline s0 is 0.836089551258839. Contrast each
  # with one low, one medium, and one high value.
  # No lower-i₀ counterfactual is plotted: experiment_panel only draws the
  # parameter variant together with the grey baseline reference.
  gamma_specs = (
    ("low", 0.2),
    ("medium", 0.6),
    ("high", 0.8),
  )
  s0_specs = (
    ("low", 0.5),
    ("medium", 0.8),
    ("high", 1.2),
  )

  # Label positions in relative-axis space. The i₀ entries are deliberately
  # absent because the i₀ effect is removed.
  label_positions = (
    is_ir=Dict(
      "IS" => (0.08, 0.08),
      "IR" => (0.88, 0.88),
      "IS (base)" => (0.42, 0.06),
      "IR (base)" => (0.88, 0.55),
    ),
    ad_as=Dict(
      "AD" => (0.08, 0.88),
      "AS" => (0.88, 0.88),
      "AD (base)" => (0.42, 0.3),
    ),
    asset_market=Dict(
      "Asset Demand" => (0.08, 0.88),
      "Asset Supply" => (0.88, 0.88),
      "Asset Demand\n(base)" => (0.42, 0.08),
    ),
  )

  baseline_solution = solve_model(Baseline)
  print_equilibrium(
    "Baseline (γ = $(baseline_solution.model.params[:γ]), s0 = $(baseline_solution.model.params[:s0]))",
    baseline_solution,
  )

  for (name, gamma_value) in gamma_specs
    variant_model = with_gamma(Baseline, gamma_value)
    solution = solve_model(variant_model)
    figure = experiment_panel(
      solution,
      baseline_solution;
      is_ir_label_positions=label_positions.is_ir,
      ad_as_label_positions=label_positions.ad_as,
      asset_market_label_positions=label_positions.asset_market,
    )
    save_figure(output_dir, "baseline_gamma_$(name)_panel", figure)
    print_equilibrium("Baseline γ=$gamma_value ($name)", solution)
  end

  for (name, s0_value) in s0_specs
    variant_model = with_s0(Baseline, s0_value)
    solution = solve_model(variant_model)
    figure = experiment_panel(
      solution,
      baseline_solution;
      is_ir_label_positions=label_positions.is_ir,
      ad_as_label_positions=label_positions.ad_as,
      asset_market_label_positions=label_positions.asset_market,
    )
    save_figure(output_dir, "baseline_s0_$(name)_panel", figure)
    print_equilibrium("Baseline s0=$s0_value ($name)", solution)
  end

  return 0


end
