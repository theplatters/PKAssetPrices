module Dynamic

import NonlinearSolve as NLS
import SciMLBase
using ADTypes
import ..ModelCore: AbstractModel, Equation
import ..ModelCore
import ..PKAssetPrices: solve_model

abstract type AbstractTimeDomain end

struct DiscreteTime <: AbstractTimeDomain
    grid::Vector{Float64}   # e.g. 0.0:1.0:100.0 collected
end


struct DynVar
    name::Symbol
    desc::String
end

struct DynamicModel{F, G} <: AbstractModel
    time::DiscreteTime
    variables::Vector{DynVar}
    params::Vector{DynVar}
    equations::Vector{Equation}
    nulls::F
    eval::G
end

struct DynamicParametrization{F, G, T <: Real, U}
    model::DynamicModel{F, G}
    params::Dict{Symbol, T}
    init::Dict{Symbol, U}
    u0::Vector{Float64}
end

struct DynamicSolution{F, G, T, U}
    model::DynamicParametrization{F, G, T, U}
    paths::Dict{Symbol, Vector{T}}
    retcodes::Vector
    max_residuals::Vector{Float64}
end

include("model_macros.jl")


function build_context(dp::DynamicParametrization{F, G, T, U}, t::Int, paths) where {F, G, T, U <: Real}
    lag_pairs = Pair{Symbol, Any}[]
    for variable in dp.model.variables
        name = variable.name
        initial = get(dp.init, name, zero(U))
        val_t1 = isone(t) ? initial : paths[name][t - 1]
        val_t2 = if isone(t)
            zero(initial)
        elseif t == 2
            initial
        else
            paths[name][t - 2]
        end
        push!(lag_pairs, Symbol(name, "[t - 1]") => val_t1)
        push!(lag_pairs, Symbol(name, "[t - 2]") => val_t2)
    end
    lag_nt = (; lag_pairs...)
    return merge(NamedTuple(dp.params), lag_nt)
end

function build_context(dp::DynamicParametrization{F, G, T, U}, t::Int, paths) where {F, G, T, U <: AbstractVector}
    lag_pairs = Pair{Symbol, Any}[]

    for s in dp.model.variables
        name = s.name
        sym_t1 = Symbol(name, "[t - 1]")
        sym_t2 = Symbol(name, "[t - 2]")

        # 1. Safely fetch initialization array (default to empty if missing)
        raw_init = get(dp.init, name, Float64[])

        # 2. Left pad with 0.0 to ensure length is at least 2
        n_missing = max(0, 2 - length(raw_init))
        init_vals = n_missing > 0 ? vcat(fill(0.0, n_missing), raw_init) : raw_init

        # Now init_vals is guaranteed to have at least 2 elements
        if isone(t)
            # init_vals[1] is t-2, init_vals[2] is t-1
            val_t1 = init_vals[2]
            val_t2 = init_vals[1]
        elseif t == 2
            val_t1 = haskey(paths, name) ? paths[name][t - 1] : 0.0
            val_t2 = init_vals[2]
        else
            val_t1 = haskey(paths, name) ? paths[name][t - 1] : 0.0
            val_t2 = haskey(paths, name) ? paths[name][t - 2] : 0.0
        end

        push!(lag_pairs, sym_t1 => val_t1)
        push!(lag_pairs, sym_t2 => val_t2)
    end

    lag_nt = (; lag_pairs...)
    return merge(NamedTuple(dp.params), lag_nt)
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
    lag_pairs = [Symbol(k, :[t - 1]) => v for (k, v) in lag]
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

function solve_model(dp::DynamicParametrization{F, G, T, U}; alg=nothing,
                     abstol=nothing, reltol=nothing, maxiters=nothing,
                     strict::Bool=true) where {F, G, T, U}
    time_span = length(dp.model.time.grid)
    m = dp.model
    paths = init_paths(m, time_span, T)


    u = copy(dp.u0)
    retcodes = Any[]
    max_residuals = Float64[]
    options = (; (name => value for (name, value) in
        ((:abstol => abstol), (:reltol => reltol), (:maxiters => maxiters))
        if !isnothing(value))...)

    for t in 1:time_span
        θt = build_context(dp, t, paths)

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

        # store period t solution into paths
        for i in eachindex(sol.u)
            paths[m.variables[i].name][t] = ut[i]
        end

        # warm start next period
        u = ut
    end

    return DynamicSolution(dp, paths, retcodes, max_residuals)
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
