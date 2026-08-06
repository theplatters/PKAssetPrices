module StaticPlotting

using ..Static
using CairoMakie

const IS_COLOR = :royalblue
const IR_COLOR = :crimson
const ASSET_COLOR = Makie.wong_colors()[1]
const LIABILITY_COLOR = Makie.wong_colors()[2]
const IS_IR_X_LIMITS = (0.0, 15.0)
const IS_IR_Y_LIMITS = (0.0, 0.2)
const AD_AS_X_LIMITS = (0.0, 15.0)
const AD_AS_Y_LIMITS = (0.0, 3.0)

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

  endpoints = sort((0.2 * value, 3.0 * value))
  return range(first(endpoints), last(endpoints); length=length)
end

"""Format model identifiers for display in plot labels."""
function display_name(name::Symbol)
  words = replace(String(name), '_' => ' ')
  words = replace(words, r"(?<=[a-z])(?=[A-Z])" => " ")
  return titlecase(words)
end

"""Return a copy of a parametrization with a lower autonomous policy rate."""
function lower_autonomous_policy_rate(
  parametrization::Static.Parametrization;
  factor::Real=0.1,
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
  lower_i0_factor::Real=0.1,
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
    label="IS curve",
  )
  lines!(
    ax,
    output_range,
    ir_values;
    color=IR_COLOR,
    linewidth=3,
    label="IR curve",
  )
  lines!(
    ax,
    output_range,
    lower_ir_values;
    color=(IR_COLOR, 0.38),
    linewidth=2,
    linestyle=:dash,
    label="IR curve (lower i₀)",
  )
  xlims!(ax, IS_IR_X_LIMITS...)
  ylims!(ax, IS_IR_Y_LIMITS...)
  axislegend(ax; position=:rt, framevisible=false, labelsize=14)
  return ax
end

"""Plot aggregate demand and aggregate supply in output–price space."""
function plot_ad_as(sol::Static.Solution, ax::Makie.Axis)
  equilibrium_curves = Static.eval_curve(sol)
  all(hasproperty(equilibrium_curves, curve) for curve in (:AD, :AS)) ||
    throw(ArgumentError("the model does not define aggregate AD and AS curves"))

  price_range = range(AD_AS_Y_LIMITS...; length=200)
  output_range = range(AD_AS_X_LIMITS...; length=200)

  vars = copy(sol.variables)
  demand_values = map(price_range) do price
    vars[:P] = price
    return Static.eval_curve(sol.model, vars).AD
  end

  vars = copy(sol.variables)
  supply_values = map(output_range) do output
    vars[:Y] = output
    return Static.eval_curve(sol.model, vars).AS
  end

  output_eq = sol.variables[:Y]
  price_eq = sol.variables[:P]
  lines!(
    ax,
    demand_values,
    price_range;
    color=IS_COLOR,
    linewidth=3,
    label="Aggregate demand",
  )
  lines!(
    ax,
    output_range,
    supply_values;
    color=IR_COLOR,
    linewidth=3,
    label="Aggregate supply",
  )
  vlines!(ax, [output_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  hlines!(ax, [price_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  scatter!(
    ax,
    [output_eq],
    [price_eq];
    color=:black,
    markersize=14,
    strokecolor=:white,
    strokewidth=2,
    label="Equilibrium",
  )
  xlims!(ax, AD_AS_X_LIMITS...)
  ylims!(ax, AD_AS_Y_LIMITS...)
  axislegend(ax; position=:rt, framevisible=false, labelsize=14)
  return ax
end

"""
Plot base-price-equivalent demand and asset supply against the asset price.

The model curve `AMD = p₁ AD / AP` values demand in units of the asset at its
base price. It is therefore comparable with the fixed quantity `AS`; it is not
the model variable `AD` itself.
"""
function plot_asset_market(
  sol::Static.Solution,
  ax::Makie.Axis;
  lower_i0_factor::Real=0.1,
)
  required_variables = (:AP, :AD, :AS)
  all(haskey(sol.variables, variable) for variable in required_variables) ||
    throw(ArgumentError("the solution does not contain an asset market"))

  equilibrium_curves = Static.eval_curve(sol)
  all(hasproperty(equilibrium_curves, curve) for curve in (:AMD, :AMS)) ||
    throw(ArgumentError("the model does not define AMD and AMS curves"))

  asset_price_eq = sol.variables[:AP]
  price_endpoints = iszero(asset_price_eq) ? (-1.0, 1.0) :
                    sort((0.55 * asset_price_eq, 1.8 * asset_price_eq))
  asset_price_range = range(first(price_endpoints), last(price_endpoints); length=200)

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

  quantity_eq = (equilibrium_curves.AMD + equilibrium_curves.AMS) / 2
  lines!(
    ax,
    demand_values,
    asset_price_range;
    color=IS_COLOR,
    linewidth=3,
    label="Demand at base price",
  )
  lines!(
    ax,
    lower_demand_values,
    asset_price_range;
    color=(IS_COLOR, 0.38),
    linewidth=2,
    linestyle=:dash,
    label="Demand (lower i₀)",
  )
  lines!(
    ax,
    supply_values,
    asset_price_range;
    color=IR_COLOR,
    linewidth=3,
    label="Asset supply",
  )
  vlines!(ax, [quantity_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  hlines!(ax, [asset_price_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  scatter!(
    ax,
    [quantity_eq],
    [asset_price_eq];
    color=:black,
    markersize=14,
    strokecolor=:white,
    strokewidth=2,
    label="Equilibrium",
  )
  axislegend(ax; position=:rt, framevisible=false, labelsize=14)
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
  position = 1.0

  for sheet in sol.sheets
    sector = display_name(sheet.sector_name)
    for (side, entries) in (
      (:asset, sheet.assets),
      (:liability, sheet.liabilities),
    )
      side_label = side == :asset ? "Assets" : "Liabilities"
      push!(tick_positions, position)
      push!(tick_labels, "$sector\n$side_label")
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
    position += 0.65
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
  )
end

"""Plot sector balance sheets as grouped vertical asset and liability bars."""
function plot_balance_sheets(sol::Static.Solution, ax::Makie.Axis)
  data = balance_sheet_plot_data(sol)
  isempty(data.positions) && return ax

  asset_indices = findall(==(:asset), data.sides)
  liability_indices = findall(==(:liability), data.sides)

  barplot!(
    ax,
    data.positions[asset_indices],
    data.values[asset_indices];
    stack=data.stacks[asset_indices],
    width=0.82,
    color=ASSET_COLOR,
    strokecolor=(:black, 0.18),
    strokewidth=1,
    bar_labels=[
      "$(replace(data.instruments[index], ' ' => '\n'))\n$(round(data.raw_values[index]; sigdigits = 4))" for
      index in asset_indices
    ],
    label_position=:center,
    label_color=:white,
    label_size=9,
    label="Assets",
  )
  barplot!(
    ax,
    data.positions[liability_indices],
    data.values[liability_indices];
    stack=data.stacks[liability_indices],
    width=0.82,
    color=LIABILITY_COLOR,
    strokecolor=(:black, 0.18),
    strokewidth=1,
    bar_labels=[
      "$(replace(data.instruments[index], ' ' => '\n'))\n$(round(data.raw_values[index]; sigdigits = 4))" for
      index in liability_indices
    ],
    label_position=:center,
    label_color=:black,
    label_size=9,
    label="Liabilities",
  )
  hlines!(ax, [0.0]; color=(:black, 0.55), linewidth=1.5)

  ax.xticks = (data.tick_positions, data.tick_labels)
  xlims!(ax, first(data.tick_positions) - 0.7, last(data.tick_positions) + 0.7)
  limit = max(maximum(data.totals), 1.0) * 1.18
  ylims!(ax, 0.0, limit)
  axislegend(
    ax;
    position=:rt,
    orientation=:horizontal,
    framevisible=false,
    labelsize=14,
  )
  return ax
end

"""
    panel(sol; size = nothing)
    panel(sol, AssetMarketPanel(); size = nothing)

Create a presentation-ready equilibrium and balance-sheet overview. The default
method contains IS–IR, AD–AS, and balance-sheet plots. Dispatch on
`AssetMarketPanel` to additionally show the asset market. Figure height grows
with the number of balance-sheet entries so labels are not clipped.
"""
panel(sol::Static.Solution; size=nothing) = panel(sol, StandardPanel(); size)

function panel(sol::Static.Solution, ::StandardPanel; size=nothing)
  entry_count = sum(length(sheet.assets) + length(sheet.liabilities) for sheet in sol.sheets)
  figure_size = isnothing(size) ? (1600, max(1120, 54 * entry_count + 620)) : size

  figure = Figure(
    size=figure_size,
    fontsize=16,
    figure_padding=(28, 38, 28, 28),
    backgroundcolor=:white,
  )
  Label(
    figure[1, 1:2],
    "Static equilibrium overview";
    fontsize=25,
    font=:bold,
    tellwidth=false,
    padding=(0, 0, 4, 4),
  )

  curve_axis = Axis(
    figure[2, 1];
    title="Goods market and interest-rate rule",
    xlabel="Output (Y)",
    ylabel="Interest rate (r)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  ad_as_axis = Axis(
    figure[2, 2];
    title="Aggregate demand and supply",
    xlabel="Output (Y)",
    ylabel="Price level (P)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  balance_axis = Axis(
    figure[3, 1:2];
    title="Sector balance sheets",
    xlabel="Sector · balance-sheet side",
    ylabel="Amount",
    xgridvisible=false,
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
    xticklabelsize=12,
    xticklabelrotation=pi / 4,
    xticklabelalign=(:right, :center),
  )

  plot_is_lm(sol, curve_axis)
  plot_ad_as(sol, ad_as_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 2, Relative(0.48))
  return figure
end

function panel(sol::Static.Solution, ::AssetMarketPanel; size=nothing)
  entry_count = sum(length(sheet.assets) + length(sheet.liabilities) for sheet in sol.sheets)
  figure_size = isnothing(size) ? (2100, max(1120, 54 * entry_count + 620)) : size

  figure = Figure(
    size=figure_size,
    fontsize=16,
    figure_padding=(28, 38, 28, 28),
    backgroundcolor=:white,
  )
  Label(
    figure[1, 1:3],
    "Static equilibrium overview";
    fontsize=25,
    font=:bold,
    tellwidth=false,
    padding=(0, 0, 4, 4),
  )

  curve_axis = Axis(
    figure[2, 1];
    title="Goods market and interest-rate rule",
    xlabel="Output (Y)",
    ylabel="Interest rate (r)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  ad_as_axis = Axis(
    figure[2, 2];
    title="Aggregate demand and supply",
    xlabel="Output (Y)",
    ylabel="Price level (P)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  asset_market_axis = Axis(
    figure[2, 3];
    title="Asset market",
    xlabel="Base-price-equivalent quantity",
    ylabel="Asset price (AP)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  balance_axis = Axis(
    figure[3, 1:3];
    title="Sector balance sheets",
    xlabel="Sector · balance-sheet side",
    ylabel="Amount",
    xgridvisible=false,
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
    xticklabelsize=12,
    xticklabelrotation=pi / 4,
    xticklabelalign=(:right, :center),
  )

  plot_is_lm(sol, curve_axis)
  plot_ad_as(sol, ad_as_axis)
  plot_asset_market(sol, asset_market_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 2, Relative(0.48))
  return figure
end

end
