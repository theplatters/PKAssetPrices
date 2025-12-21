module PKAssetPrices

using NonlinearSolve
using StaticArrays
using PrettyTables

abstract type AbstractPKModel end

export solve_model, get_nulls
export SimplePKModel, SimplePKModelParams
export PCModel, PCModelParams
export as_curve, ad_curve, ir_curve, is_curve
export get_balance_sheets, display_all_balance_sheets, SectorBalanceSheets

include("simple_model.jl")
include("asset_model.jl")
include("pc_model.jl")
include("balance_sheets.jl")

function solve_model(model::AbstractPKModel)
	p = model.params
  nulls! = get_nulls(model)
	prob = NonlinearProblem(nulls!, model.u0, p)
	sol = solve(prob)
	# Placeholder for the actual implementation of the PK model solution
	return sol
end

end # module PKAssetPrices

