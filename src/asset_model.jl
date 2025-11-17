Base.@kwdef struct AssetPKModelParams 
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

Base.@kwdef struct AssetPKModel <: AbstractPKModel
  params::AssetPKModelParams = AssetPKModelParams()
  u0::Vector = zeros(12)
end

function get_nulls(model::AssetPKModel)
  function nulls!(du, u, p::AssetPKModelParams)
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
    du[13] = b - b0 + asset_returns / r # //TODO how much is consumed is inversly related to expected returns from asset price
    du[14] = c - c0 + asset_demand                   # //TODO credit constraints somehow depend on the asset demand
    du[15] = S - r * Y                  # //TODO asset price should somehow depend on interest rate
  end
end

