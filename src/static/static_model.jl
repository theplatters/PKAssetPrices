module Static

using NonlinearSolve
using PrettyTables
using CairoMakie 
import SciMLBase
import ..ModelCore: AbstractModel, Equation
import ..ModelCore
import ..PKAssetPrices: solve_model

import Base: show, getproperty
export BalanceSheet, BalanceSheetFilled, Curve, Model, Parametrization, Solution, check_accounting
export @model, @scenario
const check_accounting = ModelCore.check_accounting


const BalanceSheet = ModelCore.BalanceSheet
const BalanceSheetFilled = ModelCore.BalanceSheetFilled

struct Curve
    name::Symbol
    arg::Symbol
    body::Expr
end

struct Model{F <: Function, C <: Function} <: AbstractModel
    variables::Vector{Symbol}
    parameters::Vector{Symbol}
    variable_descriptions::Dict{Symbol, String}
    parameter_descriptions::Dict{Symbol, String}
    equations::Vector{Equation}
    curves::Vector{Curve}
    curve_eval::C
    nulls::F
    balance_sheets::Vector{BalanceSheet}
    sheet_eval::Function
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
    retcode
    max_residual::Float64
end

include("model_macros.jl")
include("balance_sheets.jl")
include("helper_functions.jl")

include("models/asset_model.jl")
include("models/end_alpha.jl")
end
