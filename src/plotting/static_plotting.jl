module StaticPlotting

using ..Static
using CairoMakie
using Printf

const IS_COLOR = RGBf(0.5, 0.0, 0.5)
const IR_COLOR = RGBf(1.0, 0.5, 0.0)
const ASSET_COLOR = IS_COLOR
const LIABILITY_COLOR = IR_COLOR
const COUNTERFACTUAL = (IS_COLOR, 0.38)
const IS_IR_X_LIMITS = (4.0, 10.0)
const IS_IR_Y_LIMITS = (0.06, 0.15)
const AD_AS_X_LIMITS = (5.0, 9.0)
const AD_AS_Y_LIMITS = (1.2, 2.2)
const ASSET_X_LIMITS = (0.6, 1.3)
const ASSET_Y_LIMITS = (0.7, 1.3)
const BALANCE_SECTOR_GAP = 1.0

# These figures are included at `\textwidth` in `paper/teaching-note.tex`.
const FIGURE_FONT_SIZE = 20
const AXIS_TITLE_SIZE = 26
const AXIS_LABEL_SIZE = 20
const LEGEND_LABEL_SIZE = 20
const BALANCE_BAR_LABEL_SIZE = 14
const BALANCE_ACTOR_LABEL_SIZE = 20
const BALANCE_ANNOTATION_SIZE = 18
const BALANCE_TICK_LABEL_SIZE = 20

abstract type PanelVariant end

"""The default panel containing the macroeconomic curves and balance sheets."""
struct StandardPanel <: PanelVariant end

"""A panel that additionally displays asset demand and supply."""
struct AssetMarketPanel <: PanelVariant end

"""Return a plotting interval around an equilibrium value."""
function equilibrium_range(value::Real; length::Integer=200)
  if iszero(value)
    return range(-1.0, 1.0; length=length)
  end

  endpoints = sort((0.5 * value, 2.0 * value))
  return range(first(endpoints), last(endpoints); length=length)
end

"""Format model identifiers for display in plot labels."""
function display_name(name::Symbol)
  words = replace(String(name), '_' => ' ')
  words = replace(words, r"(?<=[a-z])(?=[A-Z])" => " ")
  return titlecase(words)
end

"""Return the actor name used in balance-sheet plots."""
balance_sheet_actor_name(name::Symbol) = display_name(name)

"""Use the same two-color palette for every balance-sheet side."""
function balance_sheet_segment_colors(
  instruments::AbstractVector{<:AbstractString},
  sides::AbstractVector{Symbol},
)
  return map(sides) do side
    side == :asset ? ASSET_COLOR : LIABILITY_COLOR
  end
end

function percentage_ticks()
  values = collect(0.06:0.02:0.14)
  return (values, ["$(round(Int, 100v))%" for v in values])
end

"""Return a copy of a parametrization with a lower autonomous policy rate."""
function lower_autonomous_policy_rate(
  parametrization::Static.Parametrization;
  factor::Real=0.0,
)
  0 <= factor < 1 || throw(ArgumentError("factor must satisfy 0 ≤ factor < 1"))
  rate_parameters = (:i0, :i₀, :i_0)
  rate_parameter_index = findfirst(key -> haskey(parametrization.params, key), rate_parameters)
  isnothing(rate_parameter_index) &&
    throw(ArgumentError("the model does not define an autonomous policy-rate parameter"))
  rate_parameter = rate_parameters[rate_parameter_index]

  params = copy(parametrization.params)
  params[rate_parameter] *= factor
  return Static.Parametrization(parametrization.model, params, copy(parametrization.u0))
end

"""
Plot the IS and interest-rate-rule curves on the presentation range.

A subdued counterfactual IR curve shows the effect of multiplying the
autonomous policy rate by `lower_i0_factor`.
"""
function plot_is_lm(
  sol::Static.Solution,
  ax::Makie.Axis;
  lower_i0_factor::Real=0.0,
)
  output_range = range(IS_IR_X_LIMITS...; length=200)
  rate_range = range(IS_IR_Y_LIMITS...; length=200)

  vars = copy(sol.variables)
  is_values = map(rate_range) do r
    vars[:r] = r
    return Static.eval_curve(sol.model, vars).IS
  end

  vars = copy(sol.variables)
  ir_values = map(output_range) do y
    vars[:Y] = y
    return Static.eval_curve(sol.model, vars).IR
  end

  lower_rate_model = lower_autonomous_policy_rate(sol.model; factor=lower_i0_factor)
  vars = copy(sol.variables)
  lower_ir_values = map(output_range) do y
    vars[:Y] = y
    return Static.eval_curve(lower_rate_model, vars).IR
  end

  lines!(
    ax,
    is_values,
    rate_range;
    color=IS_COLOR,
    linewidth=3,
    label="IS",
  )
  lines!(
    ax,
    output_range,
    ir_values;
    color=IR_COLOR,
    linewidth=3,
    label="IR",
  )
  lines!(
    ax,
    output_range,
    lower_ir_values;
    color=COUNTERFACTUAL,
    linewidth=2,
    linestyle=:dash,
    label="IR (lower i₀)",
  )
  xlims!(ax, IS_IR_X_LIMITS...)
  ylims!(ax, IS_IR_Y_LIMITS...)
  ax.xticks = LinearTicks(4)
  ax.yticks = percentage_ticks()
  text!(
    ax, 0.08, 0.08; text="IS", space=:relative, color=IS_COLOR,
    fontsize=LEGEND_LABEL_SIZE, align=(:left, :bottom)
  )
  text!(
    ax, 0.88, 0.88; text="IR", space=:relative, color=IR_COLOR,
    fontsize=LEGEND_LABEL_SIZE, align=(:right, :top)
  )
  text!(
    ax, 0.88, 0.72; text="IR (lower i₀)", space=:relative, color=COUNTERFACTUAL,
    fontsize=LEGEND_LABEL_SIZE - 2, align=(:right, :top)
  )
  return ax
end

"""Plot aggregate demand and aggregate supply in output–price space."""
function plot_ad_as(sol::Static.Solution, ax::Makie.Axis; lower_i0_factor::Real=0.0)
  equilibrium_curves = Static.eval_curve(sol)
  all(hasproperty(equilibrium_curves, curve) for curve in (:ADc, :ASc)) ||
    throw(ArgumentError("the model does not define aggregate ADc and ASc curves"))

  price_range = range(AD_AS_Y_LIMITS...; length=200)
  ad_as_x_limits = AD_AS_X_LIMITS
  equilibrium_output = sol.variables[:Y]
  if !(first(ad_as_x_limits) <= equilibrium_output <= last(ad_as_x_limits))
    padding = 0.25
    ad_as_x_limits = (
      min(first(AD_AS_X_LIMITS), equilibrium_output - padding),
      max(last(AD_AS_X_LIMITS), equilibrium_output + padding),
    )
  end
  output_range = range(ad_as_x_limits...; length=200)

  vars = copy(sol.variables)
  demand_values = map(price_range) do price
    vars[:P] = price
    return Static.eval_curve(sol.model, vars).ADc
  end

  vars = copy(sol.variables)
  supply_values = map(output_range) do output
    vars[:Y] = output
    return Static.eval_curve(sol.model, vars).ASc
  end

  lower_rate_model = lower_autonomous_policy_rate(sol.model; factor=lower_i0_factor)
  vars = copy(sol.variables)
  lower_ir_values = map(price_range) do price
    vars[:P] = price
    return Static.eval_curve(lower_rate_model, vars).ADc
  end

  lines!(
    ax,
    demand_values,
    price_range;
    color=IS_COLOR,
    linewidth=3,
    label="AD",
  )
  lines!(
    ax,
    output_range,
    supply_values;
    color=IR_COLOR,
    linewidth=3,
    label="AS",
  )

  lines!(
    ax,
    lower_ir_values,
    price_range;
    color=COUNTERFACTUAL,
    linewidth=2,
    linestyle=:dash,
    label="AD (lower i₀)",
  )
  xlims!(ax, ad_as_x_limits...)
  ylims!(ax, AD_AS_Y_LIMITS...)
  text!(
    ax, 0.08, 0.88; text="AD", space=:relative, color=IS_COLOR,
    fontsize=LEGEND_LABEL_SIZE, align=(:left, :top)
  )
  text!(
    ax, 0.08, 0.72; text="AD (lower i₀)", space=:relative, color=COUNTERFACTUAL,
    fontsize=LEGEND_LABEL_SIZE - 2, align=(:left, :top)
  )
  text!(
    ax, 0.88, 0.88; text="AS", space=:relative, color=IR_COLOR,
    fontsize=LEGEND_LABEL_SIZE, align=(:right, :top)
  )
  return ax
end

"""
Plot base-price-equivalent demand and asset supply against the asset price.

The model curve `AMD = p₁ AE / AP` values demand in units of the asset at its
base price. It is therefore comparable with the fixed quantity `AQ`; it is not
the model variable `AE` itself.
"""
function plot_asset_market(
  sol::Static.Solution,
  ax::Makie.Axis;
  lower_i0_factor::Real=0.0,
)
  required_variables = (:AP, :AE, :AQ)
  all(haskey(sol.variables, variable) for variable in required_variables) ||
    throw(ArgumentError("the solution does not contain an asset market"))

  equilibrium_curves = Static.eval_curve(sol)
  all(hasproperty(equilibrium_curves, curve) for curve in (:AMD, :AMS)) ||
    throw(ArgumentError("the model does not define AMD and AMS curves"))

  equilibrium_quantity = equilibrium_curves.AMD
  asset_x_limits = ASSET_X_LIMITS
  asset_y_limits = ASSET_Y_LIMITS
  uses_reference_range =
    first(ASSET_X_LIMITS) <= equilibrium_quantity <= last(ASSET_X_LIMITS) &&
    first(ASSET_Y_LIMITS) <= sol.variables[:AP] <= last(ASSET_Y_LIMITS)
  if !uses_reference_range
    asset_x_range = equilibrium_range(equilibrium_quantity)
    asset_y_range = equilibrium_range(sol.variables[:AP])
    asset_x_limits = (first(asset_x_range), last(asset_x_range))
    asset_y_limits = (first(asset_y_range), last(asset_y_range))
  end
  asset_price_range = uses_reference_range ?
                      range(ASSET_X_LIMITS...; length=200) :
                      range(asset_y_limits...; length=200)

  vars = copy(sol.variables)
  demand_values = map(asset_price_range) do asset_price
    vars[:AP] = asset_price
    return Static.eval_curve(sol.model, vars).AMD
  end

  lower_rate_model = lower_autonomous_policy_rate(sol.model; factor=lower_i0_factor)
  lower_rate_solution = Static.solve_model(lower_rate_model)
  vars = copy(lower_rate_solution.variables)
  lower_demand_values = map(asset_price_range) do asset_price
    vars[:AP] = asset_price
    return Static.eval_curve(lower_rate_solution.model, vars).AMD
  end

  vars = copy(sol.variables)
  supply_values = map(asset_price_range) do asset_price
    vars[:AP] = asset_price
    return Static.eval_curve(sol.model, vars).AMS
  end

  lines!(
    ax,
    demand_values,
    asset_price_range;
    color=IS_COLOR,
    linewidth=3,
    label="Asset Demand",
  )
  lines!(
    ax,
    supply_values,
    asset_price_range;
    color=IR_COLOR,
    linewidth=3,
    label="Asset Supply",
  )
  lines!(
    ax,
    lower_demand_values,
    asset_price_range;
    color=COUNTERFACTUAL,
    linewidth=2,
    linestyle=:dash,
    label="Demand (lower i₀)",
  )
  xlims!(ax, asset_x_limits...)
  ylims!(ax, asset_y_limits...)
  text!(
    ax, 0.08, 0.88; text="Asset Demand", space=:relative, color=IS_COLOR,
    fontsize=LEGEND_LABEL_SIZE - 1, align=(:left, :top)
  )
  text!(
    ax, 0.08, 0.68; text="Demand (lower i₀)", space=:relative, color=COUNTERFACTUAL,
    fontsize=LEGEND_LABEL_SIZE - 3, align=(:left, :top)
  )
  text!(
    ax, 0.88, 0.88; text="Asset Supply", space=:relative, color=IR_COLOR,
    fontsize=LEGEND_LABEL_SIZE - 1, align=(:right, :top)
  )
  return ax
end

"""Collect instrument segments for one asset and one liability bar per sector."""
function balance_sheet_plot_data(sol::Static.Solution)
  positions = Float64[]
  values = Float64[]
  labels = String[]
  instruments = String[]
  sides = Symbol[]
  stacks = Int[]
  raw_values = Float64[]
  tick_positions = Float64[]
  tick_labels = String[]
  totals = Float64[]
  actor_positions = Float64[]
  actor_labels = String[]
  position = 1.0

  for sheet in sol.sheets
    sector = balance_sheet_actor_name(sheet.sector_name)
    push!(actor_positions, position + 0.5)
    push!(actor_labels, sector)
    for (side, entries) in (
      (:asset, sheet.assets),
      (:liability, sheet.liabilities),
    )
      side_label = side == :asset ? "Assets" : "Liabilities"
      push!(tick_positions, position)
      push!(tick_labels, side_label)
      push!(totals, sum(abs(value) for (_, value) in entries; init=0.0))

      for (stack, (name, value)) in enumerate(entries)
        push!(positions, position)
        push!(values, abs(value))
        push!(labels, "$sector · $(display_name(name))")
        push!(instruments, display_name(name))
        push!(sides, side)
        push!(stacks, stack)
        push!(raw_values, value)
      end
      position += 1.0
    end
    position += BALANCE_SECTOR_GAP
  end

  return (;
    positions,
    values,
    labels,
    instruments,
    sides,
    stacks,
    raw_values,
    tick_positions,
    tick_labels,
    totals,
    actor_positions,
    actor_labels,
  )
end


function reserve_ratio(sol::Static.Solution)
  return sol.variables[:dR] / sol.variables[:dM]
end

function total_loans(sol::Static.Solution)
  return sol.variables[:dL]
end

function risk_indicator(sol::Static.Solution)
  asset_exposure = get(sol.variables, :SD, 0.0)
  return asset_exposure / sol.variables[:dL]
end

"""Plot sector balance sheets as grouped vertical asset and liability bars."""
function plot_balance_sheets(sol::Static.Solution, ax::Makie.Axis)
  data = balance_sheet_plot_data(sol)
  isempty(data.positions) && return ax

  segment_colors = balance_sheet_segment_colors(data.instruments, data.sides)
  abbreviation(name) = begin
    occursin("Deposit", name) ? "D" : occursin("Loan", name) ? "L" :
    occursin("Reserve", name) ? "R" : occursin("Credit", name) ? "CB" : name
  end
  barplot!(
    ax, data.positions, data.values;
    stack=data.stacks, width=0.8, color=segment_colors,
    strokecolor=(:black, 0.65),
    strokewidth=1.5,
    bar_labels=[
      @sprintf(
        "%s: %.1f", abbreviation(data.instruments[index]),
        data.raw_values[index]
      ) for index in eachindex(data.positions)
    ],
    gap=2,
    label_position=:center,
    label_color=:black,
    label_size=BALANCE_BAR_LABEL_SIZE,
  )
  hlines!(ax, [0.0]; color=(:black, 0.55), linewidth=1.5)
  vlines!(ax, [3.0, 6.0]; color=(:black, 0.35), linewidth=1.0, linestyle=:dash, ymax=6.0 / 8.0)

  text!(
    ax,
    data.actor_positions,
    fill(5.5, length(data.actor_positions));
    text=data.actor_labels,
    align=(:center, :bottom),
    font=:bold,
    fontsize=BALANCE_ACTOR_LABEL_SIZE,
    color=:black,
  )

  ax.xticks = (data.tick_positions, data.tick_labels)
  xlims!(ax, 0.3, 8.7)
  ylims!(ax, 0.0, 8.0)
  text!(
    ax,
    0.97, 0.97;
    text=join(
      [
        @sprintf("Total Debt / GDP: %.2f", total_loans(sol) / sol.variables[:Y]),
        @sprintf("Speculative debt / Total Debt: %.2f", risk_indicator(sol)),
      ],
      '\n',
    ),
    space=:relative,
    align=(:right, :top),
    fontsize=BALANCE_ANNOTATION_SIZE,
    color=(:black, 0.75),
  )
  return ax
end

"""
    panel(sol; size = nothing, title = "Static equilibrium overview")
    panel(sol, AssetMarketPanel(); size = nothing, title = "Static equilibrium overview")

Create a presentation-ready equilibrium and balance-sheet overview. The default
method contains IS–IR, AD–AS, and balance-sheet plots. Dispatch on
`AssetMarketPanel` to additionally show the asset market.
"""
panel(
  sol::Static.Solution;
  size=nothing,
  title="Static equilibrium overview",
) = panel(sol, StandardPanel(); size, title)

function panel(
  sol::Static.Solution,
  ::StandardPanel;
  size=nothing,
  title="Static equilibrium overview",
)
  figure_size = isnothing(size) ? (1400, 1000) : size

  figure = Figure(
    size=figure_size,
    fontsize=FIGURE_FONT_SIZE,
    figure_padding=(28, 38, 28, 28),
    backgroundcolor=:white,
  )

  curve_axis = Axis(
    figure[1, 1];
    title=rich("(A) ", "Goods Market Dynamics"; font=:bold),
    xlabel="Output Y", ylabel="interest rate r",
    xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
  )
  ad_as_axis = Axis(
    figure[1, 2];
    title=rich("(B) ", "Output and Inflation Dynamics"; font=:bold),
    xlabel="Output Y", ylabel="Price Level P",
    xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
  )
  balance_axis = Axis(
    figure[2, 1:2];
    title=rich("(C) ", "Sector Balance Sheets"; font=:bold),
    ylabel="Amount",
    xgridvisible=false,
    ygridcolor=(:black, 0.08),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
    xticklabelsize=BALANCE_TICK_LABEL_SIZE,
  )

  plot_is_lm(sol, curve_axis)
  plot_ad_as(sol, ad_as_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 1, Relative(0.5))
  rowsize!(figure.layout, 2, Relative(0.5))
  return figure
end

function panel(
  sol::Static.Solution,
  ::AssetMarketPanel;
  size=nothing,
  title="Static equilibrium overview",
)
  figure_size = isnothing(size) ? (1400, 1000) : size

  figure = Figure(
    size=figure_size,
    fontsize=FIGURE_FONT_SIZE,
    figure_padding=(28, 38, 28, 28),
    backgroundcolor=:white,
  )

  curve_axis = Axis(
    figure[1, 1];
    title=rich("(A) ", "Goods Market Dynamics"; font=:bold),
    xlabel="Output Y", ylabel="interest rate r",
    xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
  )
  ad_as_axis = Axis(
    figure[1, 2];
    title=rich("(B) ", "Output and Inflation Dynamics"; font=:bold),
    xlabel="Output Y", ylabel="Price Level P",
    xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
  )
  asset_market_axis = Axis(
    figure[2, 1];
    title=rich("(C) ", "Financial Market Dynamics"; font=:bold),
    xlabel="Base-price-equivalent quantity",
    ylabel="Asset Price AP",
    xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
  )
  balance_axis = Axis(
    figure[2, 2];
    title=rich("(D) ", "Sector Balance Sheets"; font=:bold),
    ylabel="Amount",
    xgridvisible=false,
    ygridcolor=(:black, 0.08),
    titlesize=AXIS_TITLE_SIZE,
    xlabelsize=AXIS_LABEL_SIZE,
    ylabelsize=AXIS_LABEL_SIZE,
    bottomspinecolor=:black, topspinecolor=:black,
    leftspinecolor=:black, rightspinecolor=:black,
    xticklabelsize=BALANCE_TICK_LABEL_SIZE,
  )

  plot_is_lm(sol, curve_axis)
  plot_ad_as(sol, ad_as_axis)
  plot_asset_market(sol, asset_market_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 1, Relative(0.5))
  rowsize!(figure.layout, 2, Relative(0.5))
  return figure
end

end
