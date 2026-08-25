module Dynamic

import NonlinearSolve as NLS
import SciMLBase
using ADTypes
import ..ModelCore: AbstractModel, Equation, lag_key, BalanceSheet, BalanceSheetFilled
import ..ModelCore
import ..PKAssetPrices: solve_model

export DynamicModel, DynamicParametrization, DynamicSolution, Shock, validate_shocks,
       validate_time_grid, sheets, check_accounting, @model, @scenario, @shock,
       set_shocks, shocks
const check_accounting = ModelCore.check_accounting

abstract type AbstractTimeDomain end

struct DiscreteTime <: AbstractTimeDomain
    grid::Vector{Float64}   # e.g. 0.0:1.0:100.0 collected
end


struct DynVar
    name::Symbol
    desc::String
end

"""
    Shock(param::Symbol, from::Float64, until::Union{Float64,Nothing}, value::Float64, source::String)

A time-windowed override of a model parameter. `Shock` is the unit of a
[`DynamicParametrization`](@ref) shock set; each entry forces `param` to
`value` over a window of the model time grid and is applied by
[`solve_model`](@ref) (and by [`shocks`](@ref)/[`set_shocks`](@ref) on the
parametrization).

# Fields
- `param::Symbol`: the overridden parameter name (must be declared by the model).
- `from::Float64`: lower bound of the window in grid time; inclusive.
- `until::Union{Float64,Nothing}`: upper bound of the window in grid time;
  `nothing` means the shock is *persistent* and applies from `from` to the end
  of the grid (the effective upper bound is `Inf`).
- `value::Float64`: the value assigned to `param` while the window is active.
- `source::String`: provenance tag for diagnostics (e.g. a macro source line,
  `"programmatic"`, or a dashboard identifier).

# Constructor
Prefer the keyword constructor, which validates inputs:

```julia
Shock(; param, from, until=nothing, value, source="programmatic")
```

- `until` defaults to `nothing`, i.e. a persistent shock.
- `from`, `until`, and `value` must each be a finite `Real` value that is
  **not** a `Bool` (`until` may instead be `nothing`). A non-finite `Real` or a
  `Bool` raises an error.
- `param` must be a `Symbol`.
- Consistency is enforced: when `until` is set, it must satisfy `until >= from`.

# Example
```julia
# Persistent shock: drift = 1.0 from grid time 2 onward.
s = Shock(param=:drift, from=2, value=1.0)

# Windowed shock: i0 = 0.05 exactly at grid time 50 (a point window).
s2 = Shock(param=:i0, from=50, until=50, value=0.05)
```
"""
struct Shock
    param::Symbol
    from::Float64
    until::Union{Float64,Nothing}
    value::Float64
    source::String

    # Keep the five-argument form available, but make it go through the same
    # checks as the keyword form.  In particular, the generated typed
    # constructor must not provide a positional validation escape hatch.
    function Shock(param, from, until, value, source)
        forms = "expected `Shock(param, from, until, value, source)` or `Shock(; param=..., from=..., until=..., value=..., source=...)`"
        param isa Symbol || error("Invalid Shock parameter $(repr(param)); offending entry/source $(repr(source)); $forms.")
        for (name, x) in (("from", from), ("until", until), ("value", value))
            ((name == "until" && x === nothing) || (x isa Real && !(x isa Bool) && isfinite(x))) ||
                error("Invalid Shock $(repr(param)) $name=$(repr(x)); offending source $(repr(source)); expected a finite Real (not Bool), with until=nothing allowed; $forms.")
        end
        until === nothing || until >= from ||
            error("Invalid Shock $(repr(param)) window from=$(repr(from)), until=$(repr(until)); offending source $(repr(source)); expected until >= from; $forms.")
        float_from, float_until, float_value = try
            (Float64(from), until === nothing ? nothing : Float64(until), Float64(value))
        catch
            error("Invalid Shock $(repr(param)) numeric conversion; offending source $(repr(source)); expected values representable as finite Float64; $forms.")
        end
        isfinite(float_from) && (float_until === nothing || isfinite(float_until)) &&
            isfinite(float_value) ||
            error("Invalid Shock $(repr(param)) numeric conversion; offending source $(repr(source)); expected values representable as finite Float64; $forms.")
        string_source = try
            String(source)
        catch
            error("Invalid Shock $(repr(param)) source=$(repr(source)); expected a String or String-convertible source; $forms.")
        end
        new(param, float_from, float_until, float_value, string_source)
    end
end

function Shock(; param, from, until=nothing, value, source="programmatic")
    return Shock(param, from, until, value, source)
end

function validate_time_grid(grid; source="programmatic")
    xs = Float64.(collect(grid))
    isempty(xs) && error("Invalid @time grid source/expression `$source`: expected non-decreasing @time grid, got empty grid.")
    all(isfinite, xs) && all(xs[i] <= xs[i+1] for i in 1:length(xs)-1) ||
        error("Invalid @time grid source/expression `$source`: expected non-decreasing @time grid with finite values.")
    return xs
end

struct DynamicModel{F, G, H} <: AbstractModel
    time::DiscreteTime
    variables::Vector{DynVar}
    params::Vector{DynVar}
    equations::Vector{Equation}
    nulls::F
    eval::G
    stocks::Vector{Symbol}
    stocks_eval::H
    balance_sheets::Vector{BalanceSheet}
    sheet_eval::Function
end

# Structs do not get a useful keyword constructor automatically.  In
# particular, the dashboard reconstructs models when changing the horizon.
function DynamicModel(; time, variables, params, equations, nulls, eval,
                       stocks=Symbol[], stocks_eval=(context -> Float64[]),
                       balance_sheets=BalanceSheet[], sheet_eval=(context -> BalanceSheetFilled[]))
    return DynamicModel(time, variables, params, equations, nulls, eval,
                        Symbol[stocks...], stocks_eval, balance_sheets, sheet_eval)
end

struct DynamicParametrization{F, G, H, T <: Real, U}
    model::DynamicModel{F, G, H}
    params::Dict{Symbol, T}
    init::Dict{Symbol, U}
    u0::Vector{Float64}
    shocks::Vector{Shock}
end

DynamicParametrization(model, params, init, u0) = DynamicParametrization(model, params, init, u0, Shock[])
function DynamicParametrization(; model, params, init, u0, shocks=Shock[])
    return DynamicParametrization(model, params, init, u0, Shock[shocks...])
end

function validate_shocks(shocks::AbstractVector, base)
    model = base isa DynamicParametrization ? base.model : base
    declared = [p.name for p in model.params]
    grid = model.time.grid
    seen = Set{Tuple{Symbol,Float64,Union{Float64,Nothing},Float64}}()
    for shock in shocks
        shock isa Shock || error("Invalid shock entry $(repr(shock)); expected Shock with source.")
        s = "Shock($(shock.param), $(shock.from), $(shock.until), $(shock.value)) source=$(repr(shock.source))"
        shock.param isa Symbol || error("$s: invalid parameter entry; expected a Symbol in the Shock constructor.")
        shock.from isa Real && !(shock.from isa Bool) && isfinite(shock.from) ||
            error("$s: invalid from entry; expected a finite Real, not Bool.")
        (shock.until === nothing || (shock.until isa Real && !(shock.until isa Bool) && isfinite(shock.until))) ||
            error("$s: invalid until entry; expected nothing or a finite Real, not Bool.")
        shock.value isa Real && !(shock.value isa Bool) && isfinite(shock.value) ||
            error("$s: invalid value entry; expected a finite Real, not Bool.")
        shock.source isa String || error("$s: invalid source; expected a String or String-convertible source.")
        shock.until === nothing || shock.until >= shock.from ||
            error("$s: reversed shock range; expected until >= from.")
        shock.param in declared || error("$s: unknown parameter; declared parameters: $(join(string.(declared), ", ")). Fix the parameter name.")
        shock.from <= last(grid) && (shock.until === nothing || shock.until >= first(grid)) ||
            error("$s lies wholly outside grid $(first(grid)):$(last(grid)); expected a window intersecting the base grid.")
        key = (shock.param, shock.from, shock.until, shock.value)
        key in seen && error("Duplicate identical $s; remove the duplicate shock entry.")
        push!(seen, key)
    end
    return shocks
end

"""Plain field accessor returning the shock vector of a parametrization.

`shocks(dp)` returns the `Vector{Shock}` attached to `dp`. It does not copy or
validate; to replace the shock set with validation, use [`set_shocks`](@ref).

# Example
```julia
dp2 = set_shocks(dp, [Shock(param=:drift, from=2, value=1.0)])
@assert shocks(dp2)[1].param === :drift
```
"""
shocks(dp::DynamicParametrization) = dp.shocks

"""Replace the shock vector of a `DynamicParametrization`, returning a new one.

`set_shocks` validates `new_shocks` against `dp.model` via [`validate_shocks`]
and returns a fresh `DynamicParametrization`. The `model` reference is shared
(`result.model === dp.model`): shocks live on the parametrization, while the
model closure is immutable by convention. `params`, `init`, `u0`, and the shock
vector are deep-copied so the input is never mutated. The new shocks *replace*
any existing ones rather than appending to them.

# Example
```julia
dp2 = set_shocks(dp, [Shock(param=:drift, from=2, value=1.0)])
@assert dp2.model === dp.model
@assert shocks(dp2)[1].param === :drift
```
"""
function set_shocks(dp::DynamicParametrization, new_shocks::Vector{Shock})
    validated = validate_shocks(new_shocks, dp)
    return DynamicParametrization(
        dp.model,
        deepcopy(dp.params),
        deepcopy(dp.init),
        deepcopy(dp.u0),
        deepcopy(validated),
    )
end

struct DynamicSolution{F, G, H, T, U}
    model::DynamicParametrization{F, G, H, T, U}
    paths::Dict{Symbol, Vector{T}}
    retcodes::Vector
    max_residuals::Vector{Float64}
    sheets::Vector{Vector{BalanceSheetFilled}}
end

include("model_macros.jl")


function _build_context(dp::DynamicParametrization, t::Int, paths, depths)
    lag_pairs = Pair{Symbol, Any}[]

    for variable in dp.model.variables
        name = variable.name
        raw_init = get(dp.init, name, Float64[])
        history_length = length(raw_init)
        for k in 1:max(2, get(depths, name, 0))
            period = t - k
            value = if period >= 1 && haskey(paths, name)
                paths[name][period]
            elseif period <= 0 && 1 <= history_length + period <= history_length
                raw_init[history_length + period]
            else
                zero(eltype(raw_init))
            end
            push!(lag_pairs, lag_key(name, k) => value)
        end
    end

    lag_nt = (; lag_pairs...)
    isempty(dp.shocks) && return merge(NamedTuple(dp.params), lag_nt)

    # Shock windows are expressed in model time, rather than in period
    # indices.  Keeping the predicate here also makes this correct for
    # truncated dashboard grids.  Pairs are deliberately collected in
    # declaration order: merge then gives later active shocks precedence.
    g = dp.model.time.grid[t]
    shock_pairs = Pair{Symbol, Any}[]
    for shock in dp.shocks
        active = shock.from <= g <= (shock.until === nothing ? Inf : shock.until)
        active && push!(shock_pairs, shock.param => shock.value)
    end
    shock_nt = (; shock_pairs...)
    return merge(NamedTuple(dp.params), shock_nt, lag_nt)
end

function build_context(dp::DynamicParametrization, t::Int, paths)
    equations = vcat(dp.model.equations,
        [Equation(:_sheet, rhs) for bs in dp.model.balance_sheets for rhs in values(bs.calculations)])
    depths = _required_lag_depths(_discover_lags(equations,
        [variable.name for variable in dp.model.variables]))
    return _build_context(dp, t, paths, depths)
end


function init_paths(m::DynamicModel, time_span::Int, ::Type{T}) where {T <: Real}
    paths = Dict{Symbol, Vector{T}}()
    for v in m.variables
        paths[v.name] = Vector{T}(undef, time_span)
    end
    return paths
end

"""Evaluate the model equations at supplied values and base parameters.

`eval_model` evaluates at base parameter values and shocks are not applied: the
parametrization's shock set is ignored and the equations are solved at the base
parameters only.  This helper is therefore intentionally independent of the
period used by `solve_model`.
"""
function eval_model(dp::DynamicParametrization, values::Dict{Symbol, Float64}, lag::Dict{Symbol, Float64})
    par_nt = (; (k => v for (k, v) in dp.params)...)
    equations = vcat(dp.model.equations,
        [Equation(:_sheet, rhs) for bs in dp.model.balance_sheets for rhs in Base.values(bs.calculations)])
    depths = _required_lag_depths(_discover_lags(equations, [v.name for v in dp.model.variables]))
    lag_values = Dict{Symbol, Float64}()
    for variable in dp.model.variables
        name = variable.name
        history = get(dp.init, name, Float64[])
        for k in 1:max(2, get(depths, name, 0))
            value = length(history) >= k ? history[end - k + 1] : 0.0
            lag_values[lag_key(name, k)] = value
        end
    end
    # Bare entries are, by documented convention, t-1 values.
    for (name, value) in lag
        lag_values[lag_key(name, 1)] = value
    end
    lag_pairs = collect(lag_values)
    lag_nt = (; lag_pairs...)
    context = merge(par_nt, lag_nt, NamedTuple(values))

    return dp.model.eval(context)
end


function _dynamic_model_label(model::DynamicModel)
    for name in names(@__MODULE__, all = true, imported = false)
        isdefined(@__MODULE__, name) || continue
        value = getfield(@__MODULE__, name)
        value isa DynamicParametrization && value.model === model && return string(name)
    end
    return "Dynamic.DynamicModel"
end

function solve_model(dp::DynamicParametrization{F, G, H, T, U}; alg=nothing,
                     abstol=nothing, reltol=nothing, maxiters=nothing,
                      strict::Bool=true) where {F, G, H, T, U}
    time_span = length(dp.model.time.grid)
    m = dp.model
    equations = vcat(m.equations,
        [Equation(:_sheet, rhs) for bs in m.balance_sheets for rhs in values(bs.calculations)])
    depths = _required_lag_depths(_discover_lags(equations, [v.name for v in m.variables]))
    paths = init_paths(m, time_span, T)


    u = copy(dp.u0)
    retcodes = Any[]
    max_residuals = Float64[]
    sheets = Vector{BalanceSheetFilled}[]
    options = (; (name => value for (name, value) in
        ((:abstol => abstol), (:reltol => reltol), (:maxiters => maxiters))
        if !isnothing(value))...)

    for t in 1:time_span
        θt = _build_context(dp, t, paths, depths)
        if !isempty(m.stocks)
            stock_values = m.stocks_eval(θt)
            length(stock_values) == length(m.stocks) ||
                error("Dynamic stock evaluator returned $(length(stock_values)) values, " *
                    "expected $(length(m.stocks)).")
            θt = merge(θt, NamedTuple(m.stocks .=> stock_values))
        end

        prob = NLS.NonlinearProblem(m.nulls, u, θt)
        solver_alg = isnothing(alg) ?
            NLS.NewtonRaphson(; autodiff = ADTypes.AutoForwardDiff()) : alg
        sol = if isempty(options)
            NLS.solve(prob, solver_alg)
        else
            NLS.solve(prob, solver_alg; options...)
        end

        ut = sol.u
        residual = m.nulls(ut, θt)
        max_residual = isempty(residual) ? 0.0 : maximum(abs, residual)
        push!(retcodes, sol.retcode)
        push!(max_residuals, max_residual)
        if !SciMLBase.successful_retcode(sol)
            label = _dynamic_model_label(m)
            message = "$label failed at period $t with retcode $(sol.retcode), max residual $(max_residual)"
            strict ? error(message) : @warn(message)
        end

        # Store predetermined stocks and solved flows separately.  Only flows
        # are warm-started: stocks are recomputed from history every period.
        for (i, name) in enumerate(m.stocks)
            paths[name][t] = θt[name]
        end
        flow_index = 0
        for variable in m.variables
            variable.name in m.stocks && continue
            flow_index += 1
            paths[variable.name][t] = ut[flow_index]
        end

        sheet_context = merge(θt, NamedTuple(variable.name => paths[variable.name][t] for variable in m.variables))
        push!(sheets, m.sheet_eval(sheet_context))

        # warm start next period
        u = copy(ut)
    end

    return DynamicSolution(dp, paths, retcodes, max_residuals, sheets)
end

"Return the filled balance sheets for period `t`; invalid periods throw BoundsError."
sheets(sol::DynamicSolution, t::Int) = sol.sheets[t]

function ModelCore.check_accounting(sol::DynamicSolution; tol=1e-8, strict=false)
    periods = [ModelCore._accounting_result(x; tol=tol, strict=strict, period=i)
               for (i, x) in enumerate(sol.sheets)]
    return (consistent=all(x -> x.consistent, periods), periods=periods)
end

function ModelCore.check_accounting(sol::DynamicSolution, t::Int; tol=1e-8, strict=false)
    return ModelCore._accounting_result(sol.sheets[t]; tol=tol, strict=strict, period=t)
end


function update_params(dp::DynamicParametrization, x::Vector{T}) where {T <: Real}
    new_params = merge(
        dp.params, Dict{Symbol, T}(
            :c₀ => x[1], :c₁ => x[2], :i0 => x[3], :i1 => x[4], :i2 => x[5],
            :s0 => x[6], :s1 => x[7], :s2 => x[8], :γ => x[9], :α₀ => x[10],
            :d0 => x[11], :d1 => x[12], :gₐ => x[13], :m => x[14]
        )
    )

    return DynamicParametrization(
        dp.model,
        new_params,
        dp.init,
        dp.u0,
        deepcopy(dp.shocks)
    )
end


include("models/models.jl")
include("models/experiments_on_ap.jl")


end
