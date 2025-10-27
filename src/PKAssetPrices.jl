module PKAssetPrices

using NonlinearSolve
using StaticArrays

abstract type AbstractPKModel end

export solve_model, SimplePKModel, SimplePKModelParams, get_nulls
export as_curve, ad_curve, ir_curve, is_curve

include("simple_model.jl")
include("asset_model.jl")

function solve_model(model::AbstractPKModel)
	p = model.params
  nulls! = get_nulls(model)
	prob = NonlinearProblem(nulls!, model.u0, p)
	sol = solve(prob)
	# Placeholder for the actual implementation of the PK model solution
	return sol
end

end # module PKAssetPrices

