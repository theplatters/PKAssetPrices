module StaticPlotting

using ..Static
using CairoMakie

const IS_COLOR = :royalblue
const IR_COLOR = :crimson
const ASSET_COLOR = Makie.wong_colors()[1]
const LIABILITY_COLOR = Makie.wong_colors()[2]

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

"""Plot the IS and interest-rate-rule curves and mark their equilibrium."""
function plot_is_lm(sol::Static.Solution, ax::Makie.Axis)
  r_eq = sol.variables[:r]
  y_eq = sol.variables[:Y]
  r_range = equilibrium_range(r_eq)
  y_range = equilibrium_range(y_eq)

  vars = copy(sol.variables)
  is_values = map(r_range) do r
    vars[:r] = r
    return Static.eval_curve(sol.model, vars).IS
  end

  vars = copy(sol.variables)
  ir_values = map(y_range) do y
    vars[:Y] = y
    return Static.eval_curve(sol.model, vars).IR
  end

  lines!(
    ax,
    r_range,
    is_values;
    color=IS_COLOR,
    linewidth=3,
    label="IS curve",
  )
  lines!(
    ax,
    ir_values,
    y_range;
    color=IR_COLOR,
    linewidth=3,
    label="IR curve",
  )
  vlines!(ax, [r_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  hlines!(ax, [y_eq]; color=(:black, 0.25), linestyle=:dot, linewidth=1.5)
  scatter!(
    ax,
    [r_eq],
    [y_eq];
    color=:black,
    markersize=14,
    strokecolor=:white,
    strokewidth=2,
    label="Equilibrium",
  )
  axislegend(ax; position=:rt, framevisible=false, labelsize=14)
  return ax
end

"""Plot asset demand and supply as functions of the asset price."""
function plot_asset_market(sol::Static.Solution, ax::Makie.Axis)
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
    label="Asset demand",
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

"""Collect mirrored balance-sheet bars, leaving space between sectors."""
function balance_sheet_plot_data(sol::Static.Solution)
  positions = Float64[]
  values = Float64[]
  labels = String[]
  sides = Symbol[]
  raw_values = Float64[]
  position = 1.0

  for sheet in sol.sheets
    sector = display_name(sheet.sector_name)
    for (side, entries, direction) in (
      (:asset, sheet.assets, 1.0),
      (:liability, sheet.liabilities, -1.0),
    )
      for (name, value) in entries
        push!(positions, position)
        push!(values, direction * abs(value))
        push!(labels, "$sector · $(display_name(name))")
        push!(sides, side)
        push!(raw_values, value)
        position += 1.0
      end
    end
    position += 0.65
  end

  return (; positions, values, labels, sides, raw_values)
end

"""Plot sector balance sheets with liabilities left and assets right of zero."""
function plot_balance_sheets(sol::Static.Solution, ax::Makie.Axis)
  data = balance_sheet_plot_data(sol)
  isempty(data.positions) && return ax

  asset_indices = findall(==(:asset), data.sides)
  liability_indices = findall(==(:liability), data.sides)

  barplot!(
    ax,
    data.positions[asset_indices],
    data.values[asset_indices];
    direction=:x,
    color=ASSET_COLOR,
    strokecolor=(:black, 0.18),
    strokewidth=1,
    label="Assets",
  )
  barplot!(
    ax,
    data.positions[liability_indices],
    data.values[liability_indices];
    direction=:x,
    color=LIABILITY_COLOR,
    strokecolor=(:black, 0.18),
    strokewidth=1,
    label="Liabilities",
  )
  vlines!(ax, [0.0]; color=(:black, 0.55), linewidth=1.5)

  value_labels = string.(round.(data.raw_values; sigdigits=4))
  for side in (:liability, :asset)
    indices = findall(==(side), data.sides)
    isempty(indices) && continue
    text!(
      ax,
      data.values[indices],
      data.positions[indices];
      text=value_labels[indices],
      align=side == :liability ? (:right, :center) : (:left, :center),
      offset=side == :liability ? (-7, 0) : (7, 0),
      fontsize=12,
    )
  end

  ax.yticks = (data.positions, data.labels)
  limit = max(maximum(abs, data.values), 1.0) * 1.32
  xlims!(ax, -limit, limit)
  # Reserve a band above the first bar for the horizontal legend.
  ylims!(ax, maximum(data.positions) + 0.8, -0.9)
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
method creates two plots. Dispatch on `AssetMarketPanel` to add an asset-market
plot. Figure height grows with the number of balance-sheet entries so labels are
not clipped.
"""
panel(sol::Static.Solution; size=nothing) = panel(sol, StandardPanel(); size)

function panel(sol::Static.Solution, ::StandardPanel; size=nothing)
  entry_count = sum(length(sheet.assets) + length(sheet.liabilities) for sheet in sol.sheets)
  figure_size = isnothing(size) ? (1600, max(720, 54 * entry_count + 220)) : size

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
    xlabel="Interest rate (r)",
    ylabel="Output (Y)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  balance_axis = Axis(
    figure[2, 2];
    title="Sector balance sheets",
    xlabel="Liabilities  ←  amount  →  assets",
    ylabel="Sector · instrument",
    xgridcolor=(:black, 0.08),
    ygridvisible=false,
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
    yticklabelsize=13,
  )

  plot_is_lm(sol, curve_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  colsize!(figure.layout, 1, Relative(0.46))
  rowgap!(figure.layout, 14)
  return figure
end

function panel(sol::Static.Solution, ::AssetMarketPanel; size=nothing)
  entry_count = sum(length(sheet.assets) + length(sheet.liabilities) for sheet in sol.sheets)
  figure_size = isnothing(size) ? (1500, max(1120, 54 * entry_count + 620)) : size

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
    xlabel="Interest rate (r)",
    ylabel="Output (Y)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  asset_market_axis = Axis(
    figure[2, 2];
    title="Asset market",
    xlabel="Asset-market quantity",
    ylabel="Asset price (AP)",
    xgridcolor=(:black, 0.08),
    ygridcolor=(:black, 0.08),
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
  )
  balance_axis = Axis(
    figure[3, 1:2];
    title="Sector balance sheets",
    xlabel="Liabilities  ←  amount  →  assets",
    ylabel="Sector · instrument",
    xgridcolor=(:black, 0.08),
    ygridvisible=false,
    titlesize=19,
    xlabelsize=16,
    ylabelsize=16,
    yticklabelsize=13,
  )

  plot_is_lm(sol, curve_axis)
  plot_asset_market(sol, asset_market_axis)
  plot_balance_sheets(sol, balance_axis)

  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 2, Relative(0.48))
  return figure
end

end
