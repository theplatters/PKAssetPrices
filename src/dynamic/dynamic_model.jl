module Dynamic

import NonlinearSolve as NLS
import SciMLBase
using ADTypes
import ..ModelCore: AbstractModel, Equation, lag_key, BalanceSheet, BalanceSheetFilled
import ..ModelCore
import ..PKAssetPrices: solve_model

export DynamicModel, DynamicParametrization, DynamicSolution, sheets, check_accounting, @model, @scenario
const check_accounting = ModelCore.check_accounting

abstract type AbstractTimeDomain end

struct DiscreteTime <: AbstractTimeDomain
    grid::Vector{Float64}   # e.g. 0.0:1.0:100.0 collected
end


struct DynVar
    name::Symbol
    desc::String
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
    return merge(NamedTuple(dp.params), lag_nt)
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
        dp.u0
    )
end


include("models/models.jl")
include("models/experiments_on_ap.jl")


end
