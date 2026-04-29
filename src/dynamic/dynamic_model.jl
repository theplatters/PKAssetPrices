module Dynamic

import NonlinearSolve as NLS
using ADTypes
import ..BaseModels: AbstractModel, Equation
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

struct DynamicParametrization{F, G, T <: Real, U <: Real}
    model::DynamicModel{F, G}
    params::Dict{Symbol, T}
    init::Dict{Symbol, U}
    u0::Vector{Float64}
end

struct DynamicSolution{F, G, T <: Real, U <: Real}
    model::DynamicParametrization{F, G, T, U}
    paths::Dict{Symbol, Vector{T}}
end

include("model_macros.jl")


function build_context(dp::DynamicParametrization, t::Int, paths)
    # base params (β, α, …), scalar or vector[t]
    lag_pairs = isone(t) ? 
        [Symbol(s.name, :[t - 1]) => get!(dp.init, s.name, 0.0) for s in dp.model.variables] : 
        [Symbol(s.name, :[t - 1]) => paths[s.name][t - 1] for s in dp.model.variables]
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


function solve_model(dp::DynamicParametrization{F, G, T, U}) where {F, G, T <: Real, U <: Real}
    time_span = length(dp.model.time.grid)
    m = dp.model
    paths = init_paths(m, time_span, T)


    u = copy(dp.u0)

    for t in 1:time_span
        θt = build_context(dp, t, paths)

        prob = NLS.NonlinearProblem(m.nulls, u, θt)
        sol = NLS.solve(prob, NLS.NewtonRaphson(; autodiff = ADTypes.AutoForwardDiff()))

        ut = sol.u

        # store period t solution into paths
        for i in eachindex(sol.u)
            paths[m.variables[i].name][t] = ut[i]
        end

        # warm start next period
        u = ut
    end

    return DynamicSolution(dp, paths)
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


end
