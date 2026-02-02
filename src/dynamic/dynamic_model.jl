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


struct DynamicModel{F} <: AbstractModel
    time::DiscreteTime
    stocks::Vector{DynVar}            # time-varying variables
    flows::Vector{DynVar}
    params::Vector{DynVar}          # time-invariant parameters
    equations::Vector{Equation}     # convention: may reference x[t], x[t-1], etc.
    nulls::F
end

struct DynamicParametrization{F}
    model::DynamicModel{F}
    params::Dict{Symbol, Union{Float64, Vector{Float64}}}                 # β, α, ...
    init::Dict{Symbol, Float64}                   # x(0) or x(1)
    u0::Vector{Float64}
end

struct DynamicSolution{F}
    model::DynamicParametrization{F}
    paths::Dict{Symbol, Vector{Float64}}          # x[t] for each time-varying var
end

include("model_macros.jl")

# Pick scalar as-is, vector by time index
@inline _at(v::Float64, ::Int) = v
@inline _at(v::AbstractVector{<:Real}, t::Int) = float(v[t])

# Build a NamedTuple for this time t:
# - params: scalar or time-indexed
# - exog: time-indexed
# - lags: previous-period values of selected variables
function build_context(dp::DynamicParametrization, t::Int, paths::Dict{Symbol, Vector{Float64}})
    # base params (β, α, …), scalar or vector[t]
    par_nt = (; (k => _at(v, t) for (k, v) in dp.params)...)
    lag_pairs = isone(t) ? [Symbol(s.name, :[t - 1]) => dp.init[s.name] for s in dp.model.stocks] : [Symbol(s.name, :[t - 1]) => paths[s.name][t - 1] for s in dp.model.stocks]
    lag_nt = (; lag_pairs...)
    return merge(par_nt, lag_nt)
end

function init_paths(m::DynamicModel, T::Int)
    paths = Dict{Symbol, Vector{Float64}}()
    for v in m.flows
        paths[v.name] = Vector{Float64}(undef, T)
    end
    for v in m.stocks
        paths[v.name] = Vector{Float64}(undef, T)
    end
    return paths
end


function solve_model(dp::DynamicParametrization)
    T = length(dp.model.time.grid)
    m = dp.model
    paths = init_paths(m, T)

    nF = length(m.flows)
    nS = length(m.stocks)

    # initial guess for unknowns each period
    u = copy(dp.u0)                     # should be length nF+nS
    @assert length(u) == nF + nS

    for t in 1:T
        θt = build_context(dp, t, paths)

        prob = NonlinearProblem(m.nulls, u, θt)
        sol = solve(prob)

        ut = sol.u

        # store period t solution into paths
        for i in 1:nF
            paths[m.flows[i].name][t] = ut[i]
        end
        for i in 1:nS
            paths[m.stocks[i].name][t] = ut[nF + i]
        end

        # warm start next period
        u .= ut
    end

    return DynamicSolution(dp, paths)
end


end
