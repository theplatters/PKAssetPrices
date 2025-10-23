module PKAssetPrices

using NonlinearSolve
abstract type AbstractPKModel end
using Plots

export solve_model, SimplePKModel, SimplePKModelParams
export as_curve, ad_curve, ir_curve, is_curve

Base.@kwdef struct SimplePKModelParams
	b::Float64 = 0.5
	c::Float64 = 0.8
	d_0::Float64 = 5.0
	d_1::Float64 = 0.8
	i_0::Float64 = 0.01
	i_1::Float64 = 0.5
	m::Float64 = 0.15
	k::Float64 = 0.3
	n::Float64 = 0.15
	W_0::Float64 = 2.0
	h::Float64 = 0.8
	a::Float64 = 0.8
	Nᶠ::Float64 = 12.0
end

struct SimplePKModel <: AbstractPKModel
	params::SimplePKModelParams
end

function nulls!(du, u, p::SimplePKModelParams)
	(; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = p
	Y, ND, D, r, i, P, dL, dM, dR, W, N, U = u
	du[1] = Y - ND - c * D
	du[2] = ND - b * Y
	du[3] = D - d_0 + d_1 * r
	du[4] = i - i_0 - i_1 * P
	du[5] = r - (1 + m) * i
	du[6] = dL - c * D
	du[7] = dM - dL
	du[8] = dR - k * dM
	du[9] = P - (1 + n) * a * W
	du[10] = W - W_0 + h * U
	du[11] = N - a * Y
	du[12] = U - 1 + N / Nᶠ
end

function is_curve(r,params::SimplePKModelParams)
  (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = params
  
  (1/(1-b)) * (c *(d_0 - d_1 * r))
end

function ir_curve(Y, params::SimplePKModelParams)
  (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = params

  (1 + m)* (i_0 + i_1 * (1 + n) * a * (W_0 - h * (1 - (a * Y) / Nᶠ)))
end

function ad_curve(P, params::SimplePKModelParams)
	(; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = params

	(1/(1-b)) * (c * (d_0 - d_1 * ((1 + m) * (i_0 + i_1 * P))))
end

function as_curve(Y, params::SimplePKModelParams)
	(; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = params

	(1 + n) * a * (W_0 - h * (1 - (a * Y) / Nᶠ))
end


function solve_model(model::SimplePKModel)
	p = model.params
	u0 = zeros(12)
	prob = NonlinearProblem(nulls!, u0, p)
	sol = solve(prob)
	# Placeholder for the actual implementation of the PK model solution
	return sol
end

end # module PKAssetPrices

