module StaticPlotting

using ..Static
using CairoMakie
using Printf

const IS_COLOR = RGBf(0.5, 0.0, 0.5)
const IR_COLOR = RGBf(1.0, 0.5, 0.0)
const ASSET_COLOR = IS_COLOR
const LIABILITY_COLOR = IR_COLOR
const REFERENCE_COLOR = RGBf(0.45, 0.45, 0.45)
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

struct LabelSpec{A}
  position::Point2f
  attributes::A
end

function LabelSpec(position; attributes...)
  return LabelSpec(Point2f(position...), (; attributes...))
end

function reposition_labels(labels, positions)
  return Dict(
    label => LabelSpec(
      get(positions, label, spec.position);
      spec.attributes...,
    )
    for (label, spec) in labels
  )
end

const STANDARD_IS_IR_LABELS = Dict(
  "IS" => LabelSpec(
    (0.08, 0.08); space=:relative, align=(:left, :bottom)
  ),
  "IR" => LabelSpec((0.88, 0.88); space=:relative, align=(:right, :top)),
  "IR (lower i₀)" => LabelSpec((0.88, 0.72), space=:relative, align=(:right, :top)),
  "IS (base)" => LabelSpec((0.42, 0.06), space=:relative, align=(:left, :bottom))
)

const STANDARD_AD_AS_LABELS = Dict(
  "AD" => LabelSpec(
    (0.08, 0.88);
    space=:relative,
    align=(:left, :top),
  ),
  "AD (lower i₀)" => LabelSpec(
    (0.08, 0.72);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 2,
    align=(:left, :top),
  ),
  "AS" => LabelSpec(
    (0.88, 0.88);
    space=:relative,
    align=(:right, :top),
  ),
  "AD (base)" => LabelSpec(
    (0.42, 0.3);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 2,
    align=(:left, :bottom),
  ),
)

const STANDARD_ASSET_MARKET_LABELS = Dict(
  "Asset Demand" => LabelSpec(
    (0.08, 0.88);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 1,
    align=(:left, :top),
  ),
  "Demand (lower i₀)" => LabelSpec(
    (0.08, 0.68);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 3,
    align=(:left, :top),
  ),
  "Asset Supply" => LabelSpec(
    (0.88, 0.88);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 1,
    align=(:right, :top),
  ),
  "Demand (base)" => LabelSpec(
    (0.42, 0.08);
    space=:relative,
    fontsize=LEGEND_LABEL_SIZE - 2,
    align=(:left, :bottom),
  ),
)


abstract type PanelVariant end

"""The default panel containing the macroeconomic curves and balance sheets."""
struct StandardPanel <: PanelVariant end

"""A panel that additionally displays asset demand and supply."""
struct AssetMarketPanel <: PanelVariant end

"""Return a plotting interval around an equilibrium value."""
function equilibrium_lims(value::Real)
  if iszero(value)
    return (-1.0, 1.0)
  end

  return (0.5 * value, 2.0 * value)
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


function plot_curves!(ax, curves)
  for curve in curves
    lines!(
      ax,
      curve.x,
      curve.y;
      label=curve.label,
      curve.attributes...,
    )
  end

  return nothing
end

calculate_curve_path(sol, curve, variable, variable_range) = calculate_curve_path(sol, sol.model, curve, variable, variable_range)

function calculate_curve_path(sol, model, curve, variable, variable_range)
  vars = copy(sol.variables)
  return map(variable_range) do var
    vars[variable] = var
    return getproperty(Static.eval_curve(model, vars), curve)
  end
end

abstract type AbstractOrientation end
struct X <: AbstractOrientation end
struct Y <: AbstractOrientation end

struct Curve{S<:Static.Solution,A<:AbstractOrientation,AT}
  label::String
  curve_name::Symbol
  variable::Symbol
  sol::S
  orientation::A
  attributes::AT
end


struct PlotSpecs{C,L}
  x_limits::NTuple{2,Float64}
  y_limits::NTuple{2,Float64}
  curves::C
  labels::L
end
mutable struct PlotSpecsBuilder{AT,L}
  x_limits::NTuple{2,Float64}
  y_limits::NTuple{2,Float64}
  curves::Vector{Curve}
  labels::L
  default_attributes::AT
end

function PlotSpecsBuilder(
  x_limits,
  y_limits;
  labels,
  default_attributes...,
)
  return PlotSpecsBuilder(
    Float64.(x_limits),
    Float64.(y_limits),
    Curve[],
    labels,
    (; default_attributes...),
  )
end

function add_curve!(
  builder::PlotSpecsBuilder,
  label,
  curve_name,
  variable,
  sol,
  orientation::AbstractOrientation;
  attributes...,
)
  style = merge(
    builder.default_attributes,
    (; attributes...),
  )

  curve = Curve(
    String(label),
    curve_name,
    variable,
    sol,
    orientation,
    style,
  )

  push!(builder.curves, curve)
  return builder
end

function x_curve!(
  builder::PlotSpecsBuilder,
  label,
  curve_name,
  variable,
  sol;
  attributes...,
)
  return add_curve!(
    builder,
    label,
    curve_name,
    variable,
    sol,
    X();
    attributes...,
  )
end

function y_curve!(
  builder::PlotSpecsBuilder,
  label,
  curve_name,
  variable,
  sol;
  attributes...,
)
  return add_curve!(
    builder,
    label,
    curve_name,
    variable,
    sol,
    Y();
    attributes...,
  )
end

function build(builder::PlotSpecsBuilder)
  isempty(builder.curves) &&
    throw(ArgumentError("a plot must contain at least one curve"))

  return PlotSpecs(
    builder.x_limits,
    builder.y_limits,
    Tuple(builder.curves),
    builder.labels
  )
end

function curve_coordinates(curve::Curve{<:Any,<:X}, x_range, y_range)
  values = calculate_curve_path(
    curve.sol,
    curve.curve_name,
    curve.variable,
    y_range,
  )

  return values, y_range
end

function curve_coordinates(curve::Curve{<:Any,<:Y}, x_range, y_range)
  values = calculate_curve_path(
    curve.sol,
    curve.curve_name,
    curve.variable,
    x_range,
  )

  return x_range, values
end

function plot_curve_label!(ax, curve, labels)
  label_spec = get(labels, curve.label, nothing)
  isnothing(label_spec) && return nothing

  attributes = merge(
    (
      space=:relative,
      color=get(curve.attributes, :color, :black),
      fontsize=LEGEND_LABEL_SIZE,
    ),
    label_spec.attributes,
  )

  text!(
    ax,
    label_spec.position...;
    text=curve.label,
    attributes...,
  )

  return nothing
end

function plot_specs!(ax::Makie.Axis, specs::PlotSpecs)
  x_range = range(specs.x_limits...; length=200)
  y_range = range(specs.y_limits...; length=20)

  for curve in specs.curves
    x, y = curve_coordinates(curve, x_range, y_range)

    lines!(
      ax,
      x,
      y;
      label=curve.label,
      curve.attributes...,
    )
    plot_curve_label!(ax, curve, specs.labels)
  end

  xlims!(ax, specs.x_limits...)
  ylims!(ax, specs.y_limits...)

  return ax
end

function build_plot_specs(f, x_limits, y_limits; labels, attributes...)
  builder = PlotSpecsBuilder(
    x_limits,
    y_limits
    ;
    labels,
    attributes...,
  )

  f(builder)
  return build(builder)
end

"""
Plot the IS and interest-rate-rule curves on the presentation range.

A subdued counterfactual IR curve shows the effect of multiplying the
autonomous policy rate by `lower_i0_factor`.
"""
function plot_is_ir(
  sol::Static.Solution,
  ax::Makie.Axis;
  lower_i0_factor::Real=0.0,
  reference_solution::Union{Nothing,Static.Solution}=nothing,
  labels
)

  lower_rate_solution = lower_autonomous_policy_rate(sol.model, factor=lower_i0_factor) |> Static.solve_model


  specs = build_plot_specs(
    IS_IR_X_LIMITS,
    IS_IR_Y_LIMITS;
    labels,
    linewidth=3,
    linestyle=:solid,
  ) do builder
    x_curve!(builder, "IS", :IS, :r, sol; color=IS_COLOR)
    y_curve!(builder, "IR", :IR, :Y, sol; color=IR_COLOR)

    y_curve!(
      builder,
      "IR (lower i₀)",
      :IR,
      :Y,
      lower_rate_solution;
      color=COUNTERFACTUAL,
      linewidth=2,
      linestyle=:dash,
    )

    if (!isnothing(reference_solution))
      x_curve!(builder, "IS (base)", :IS, :r, reference_solution, color=REFERENCE_COLOR, linewidth=2.5)
    end
  end
  plot_specs!(ax, specs)

  return ax
end

"""Plot aggregate demand and aggregate supply in output–price space."""
function plot_ad_as(
  sol::Static.Solution,
  ax::Makie.Axis;
  labels,
  lower_i0_factor::Real=0.0,
  reference_solution::Union{Nothing,Static.Solution}=nothing,
)
  equilibrium_curves = Static.eval_curve(sol)
  all(hasproperty(equilibrium_curves, curve) for curve in (:ADc, :ASc)) ||
    throw(ArgumentError("the model does not define aggregate ADc and ASc curves"))

  ad_as_x_limits = AD_AS_X_LIMITS
  equilibrium_output = sol.variables[:Y]
  if !(first(ad_as_x_limits) <= equilibrium_output <= last(ad_as_x_limits))
    padding = 0.25
    ad_as_x_limits = (
      min(first(AD_AS_X_LIMITS), equilibrium_output - padding),
      max(last(AD_AS_X_LIMITS), equilibrium_output + padding),
    )
  end


  lower_rate_model = lower_autonomous_policy_rate(sol.model; factor=lower_i0_factor)
  lower_rate_solution = Static.solve_model(lower_rate_model)

  specs = build_plot_specs(
    ad_as_x_limits,
    AD_AS_Y_LIMITS;
    labels,
    linewidth=3,
    linestyle=:solid,
  ) do builder
    x_curve!(builder, "AD", :ADc, :P, sol; color=IS_COLOR)
    y_curve!(builder, "AS", :ASc, :Y, sol; color=IR_COLOR)

    x_curve!(
      builder,
      "AD (lower i₀)",
      :ADc,
      :P,
      lower_rate_solution;
      color=COUNTERFACTUAL,
      linewidth=2,
      linestyle=:dash,
    )

    if (!isnothing(reference_solution))
      lowered_reference_model = lower_autonomous_policy_rate(reference_solution.model, factor=lower_i0_factor)
      lowered_reference_solution = Static.solve_model(lowered_reference_model)
      x_curve!(builder, "AD (base)", :ADc, :P, reference_solution, color=REFERENCE_COLOR, linewidth=2.5)
      x_curve!(builder, "AD (base lower i₀)", :ADc, :P, lowered_reference_solution, color=REFERENCE_COLOR, linewidth=2.0, linestyle=:dash)
    end
  end
  plot_specs!(ax, specs)

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
  labels,
  lower_i0_factor::Real=0.0,
  reference_solution::Union{Nothing,Static.Solution}=nothing,
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
    asset_x_limits = equilibrium_lims(equilibrium_quantity)
    asset_y_limits = equilibrium_lims(sol.variables[:AP])
  end

  lower_rate_model = lower_autonomous_policy_rate(sol.model; factor=lower_i0_factor)
  lower_rate_solution = Static.solve_model(lower_rate_model)

  specs = build_plot_specs(
    asset_x_limits,
    asset_y_limits;
    labels,
    linewidth=3,
    linestyle=:solid,
  ) do builder
    x_curve!(builder, "Asset Demand", :AMD, :AP, sol; color=IS_COLOR)
    x_curve!(builder, "Asset Supply", :AMS, :AP, sol; color=IR_COLOR)

    x_curve!(
      builder,
      "Demand (lower i₀)",
      :AMD,
      :AP,
      lower_rate_solution;
      color=COUNTERFACTUAL,
      linewidth=2,
      linestyle=:dash,
    )

    if (!isnothing(reference_solution))
      lowered_reference_model = lower_autonomous_policy_rate(reference_solution.model, factor=lower_i0_factor)
      lowered_reference_solution = Static.solve_model(lowered_reference_model)
      x_curve!(builder, "Demand (base)", :AMD, :AP, reference_solution, color=REFERENCE_COLOR, linewidth=2.5)
      x_curve!(builder, "Demand (base lower i₀)", :AMD, :AP, lowered_reference_solution, color=REFERENCE_COLOR, linewidth=2.0, linestyle=:dash)
    end
  end


  plot_specs!(ax, specs)


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


_panel_figure(figure_size) = Figure(
  size=figure_size,
  fontsize=FIGURE_FONT_SIZE,
  figure_padding=(28, 38, 28, 28),
  backgroundcolor=:white,
)

_curve_axis(figure_pos) = Axis(
  figure_pos;
  title=rich("(A) ", "Goods Market Dynamics"; font=:bold),
  xlabel="Output Y", ylabel="interest rate r",
  xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
  titlesize=AXIS_TITLE_SIZE,
  xlabelsize=AXIS_LABEL_SIZE,
  ylabelsize=AXIS_LABEL_SIZE,
  bottomspinecolor=:black, topspinecolor=:black,
  leftspinecolor=:black, rightspinecolor=:black,
)

_ad_as_axis(figure_pos) = Axis(
  figure_pos;
  title=rich("(B) ", "Output and Inflation Dynamics"; font=:bold),
  xlabel="Output Y", ylabel="Price Level P",
  xgridcolor=(:black, 0.12), ygridcolor=(:black, 0.12),
  titlesize=AXIS_TITLE_SIZE,
  xlabelsize=AXIS_LABEL_SIZE,
  ylabelsize=AXIS_LABEL_SIZE,
  bottomspinecolor=:black, topspinecolor=:black,
  leftspinecolor=:black, rightspinecolor=:black,
)

_asset_market_axis(figure_pos) = Axis(
  figure_pos;
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

_balance_axis(figure_pos) = Axis(
  figure_pos;
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


function _set_gaps!(figure)
  colgap!(figure.layout, 42)
  rowgap!(figure.layout, 22)
  rowsize!(figure.layout, 1, Relative(0.5))
  return rowsize!(figure.layout, 2, Relative(0.5))
end

struct StandardPanelAxis{C,A,B}
  curve_axis::C
  ad_as_axis::A
  balance_axis::B
end

struct AssetPanelAxis{C,A,AS,B}
  curve_axis::C
  ad_as_axis::A
  asset_market_axis::AS
  balance_axis::B
end

function _get_axis(figure, ::StandardPanel)
  curve_axis = _curve_axis(figure[1, 1])
  ad_as_axis = _ad_as_axis(figure[1, 2])
  balance_axis = _balance_axis(figure[2, 1:2])


  return StandardPanelAxis(curve_axis, ad_as_axis, balance_axis)
end

function _get_axis(figure, ::AssetMarketPanel)
  curve_axis = _curve_axis(figure[1, 1])
  ad_as_axis = _ad_as_axis(figure[1, 2])

  asset_market_axis = _asset_market_axis(figure[2, 1])
  balance_axis = _balance_axis(figure[2, 2])

  return AssetPanelAxis(curve_axis, ad_as_axis, asset_market_axis, balance_axis)
end


function _fill_axis(
  sol,
  axis;
  is_ir_label_positions,
  ad_as_label_positions,
  asset_market_label_positions,
  lower_i0_factor=nothing,
  reference_solution=nothing,
)
  kwargs = (; reference_solution, lower_i0_factor)


  is_ir_labels = reposition_labels(STANDARD_IS_IR_LABELS, is_ir_label_positions)
  plot_is_ir(sol, axis.curve_axis; labels=is_ir_labels, kwargs...)
  plot_ad_as(sol, axis.ad_as_axis; labels=STANDARD_AD_AS_LABELS, kwargs...)
  _plot_asset_market(sol, axis; labels=STANDARD_ASSET_MARKET_LABELS, kwargs...)
  plot_balance_sheets(sol, axis.balance_axis)

  return nothing
end

_plot_asset_market(sol, ::StandardPanelAxis; kwargs...) = nothing

function _plot_asset_market(sol, axis::AssetPanelAxis; kwargs...)
  plot_asset_market(sol, axis.asset_market_axis; kwargs...)
  return nothing
end

"""
    panel(sol; size = nothing)
    panel(sol, AssetMarketPanel(); size = nothing,
          reference_solution = nothing, lower_i0_factor = 0.0)

Create a presentation-ready equilibrium and balance-sheet overview. The default
method contains IS–IR, AD–AS, and balance-sheet plots. Dispatch on
`AssetMarketPanel` to additionally show the asset market. The
`AssetMarketPanel` method accepts `lower_i0_factor` and `reference_solution`;
when a reference solution is supplied, the three curve plots show grey base
reference curves (and dashed lower-policy-rate reference curves where
applicable). The existing, unused `title` keyword remains accepted unchanged.
"""
function panel(
  sol::Static.Solution,
  panel_type;
  label_positions,
  size=nothing,
  reference_solution=nothing,
  lower_i0_factor=0.0,
)
  figure_size = isnothing(size) ? (1400, 1000) : size

  figure = _panel_figure(figure_size)

  axis = _get_axis(figure, panel_type)
  _fill_axis(
    sol, axis; reference_solution,
    lower_i0_factor,
  )

  _set_gaps!(figure)
  return figure
end


end
