module Static

using NonlinearSolve
import ..BaseModels: AbstractModel, Equation

export BalanceSheet, BalanceSheetFilled, Curve, Model, Parametrization, Solution
export solve_model
export @model, @scenario


struct BalanceSheet
    name::Symbol
    fields::Vector{Symbol}
    assets::Vector{Symbol}
    liabilities::Vector{Symbol}
    calculations::Dict{Symbol, Union{Symbol, Expr}}
end

struct Curve
    name::Symbol
    arg::Symbol
    body::Expr
end

struct BalanceSheetFilled
    sector_name::Symbol
    assets::Vector{Pair{Symbol, Float64}}
    liabilities::Vector{Pair{Symbol, Float64}}
end

struct Model{F <: Function, C <: Function} <: AbstractModel
    variables::Vector{Symbol}
    parameters::Vector{Symbol}
    variable_descritpions::Dict{Symbol, String}
    parameter_descritpions::Dict{Symbol, String}
    equations::Vector{Equation}
    curves::Vector{Curve}
    curve_eval::C
    nulls::F
    balance_sheets::Vector{BalanceSheet}
end

struct Parametrization{F <: Function, C <: Function}
    model::Model{F, C}
    params::Dict{Symbol, Float64}
    u0::Vector{Float64}
end

struct Solution{F <: Function, C <: Function}
    variables::Dict{Symbol, Float64}
    model::Parametrization{F, C}
    sheets::Vector{BalanceSheetFilled}
end

include("model_macros.jl")
include("balance_sheets.jl")
include("helper_functions.jl")

include("models/asset_model.jl")
include("models/pc_model.jl")
include("models/simple_model.jl")
end
