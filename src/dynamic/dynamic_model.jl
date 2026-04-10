module Dynamic

using NonlinearSolve

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


struct DynamicModel{F,G} <: AbstractModel
    time::DiscreteTime
    variables::Vector{DynVar}
    params::Vector{DynVar}
    equations::Vector{Equation}
    nulls::F
    eval::G
end

struct DynamicParametrization{F,G}
    model::DynamicModel{F, G}
    params::Dict{Symbol, Union{Float64, Vector{Float64}}}
    init::Dict{Symbol, Float64}
    u0::Vector{Float64}
end

struct DynamicSolution{F,G}
    model::DynamicParametrization{F,G}
    paths::Dict{Symbol, Vector{Float64}}
end

include("model_macros.jl")

# Pick scalar as-is, vector by time index
@inline _at(v::Float64, ::Int) = v
@inline _at(v::AbstractVector{<:Real}, t::Int) = float(v[t])

function build_context(dp::DynamicParametrization, t::Int, paths::Dict{Symbol, Vector{Float64}})
    # base params (β, α, …), scalar or vector[t]
    par_nt = (; (k => _at(v, t) for (k, v) in dp.params)...)
    lag_pairs = isone(t) ? [Symbol(s.name, :[t - 1]) => get!(dp.init, s.name, 0.0) for s in dp.model.variables] : [Symbol(s.name, :[t - 1]) => paths[s.name][t - 1] for s in dp.model.variables]
    lag_nt = (; lag_pairs...)
    return merge(par_nt, lag_nt)
end

function init_paths(m::DynamicModel, T::Int)
    paths = Dict{Symbol, Vector{Float64}}()
    for v in m.variables
        paths[v.name] = Vector{Float64}(undef, T)
    end
    return paths
end

function eval_model(dp::DynamicParametrization, values:: Dict{Symbol, Float64}, lag::Dict{Symbol, Float64})
    par_nt = (; (k => v for (k, v) in dp.params)...)
    lag_pairs = [Symbol(k, :[t - 1]) => v for (k,v) in lag]
    lag_nt = (; lag_pairs...)
    context =  merge(par_nt, lag_nt, NamedTuple(values))
    
    dp.model.eval(context)
end


function solve_model(dp::DynamicParametrization)
    T = length(dp.model.time.grid)
    m = dp.model
    paths = init_paths(m, T)


    u = copy(dp.u0)

    for t in 1:T
        θt = build_context(dp, t, paths)

        prob = NonlinearProblem(m.nulls, u, θt)
        sol = solve(prob)

        ut = sol.u

        # store period t solution into paths
        for i in eachindex(sol.u)
            paths[m.variables[i].name][t] = ut[i]
        end

        # warm start next period
        u .= ut
    end

    return DynamicSolution(dp, paths)
end


end
