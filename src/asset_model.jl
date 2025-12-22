Base.@kwdef struct AssetPKModelParams 
	b::Float64 = 0.5
	c::Float64 = 0.8
	d_0::Float64 = 5.0
	d_1::Float64 = 8
	i_0::Float64 = 0.01
	i_1::Float64 = 0.05
	m::Float64 = 0.15
	k::Float64 = 0.3
	n::Float64 = 0.15
	W_0::Float64 = 2.0
	h::Float64 = 0.8
	a::Float64 = 0.8
	Nᶠ::Float64 = 12.0
  p0::Float64 = 0.0
  p1::Float64 = 1.0
  s0::Float64 = 0.5
  s1::Float64 = 1.0
  γ0::Float64 = 0.0
  γ::Float64 = 0.5
  α::Float64 = 0.1
  gₐ::Float64 = 0.03
  AQ::Float64 = 6.0
end

Base.@kwdef struct AssetPKModel <: AbstractPKModel
  params::AssetPKModelParams = AssetPKModelParams()
  u0::Vector = ones(16)
end

function get_nulls(model::AssetPKModel)
  function nulls!(du, u, p::AssetPKModelParams)
    (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ, γ0, s0, s1, p0,p1,  γ,α , gₐ, AQ) = p
    Y, ND, D, i, r, dL, dM, dR, P, W, N, U, SD, AD, AP, AS = u
    du[1] = Y - ND - c * D
    du[2] = ND - b * Y
    du[3] = D - d_0 + d_1 * r
    du[4] = i - i_0 - i_1 * P
    du[5] = r - (1 + m) * i
    du[6] = dL - c * D - SD
    du[7] = dM - dL
    du[8] = dR - k * dM
    du[9] = P - (1 + n) * a * W
    du[10] = W - W_0 + h * U
    du[11] = N - a * Y
    du[12] = U - 1 + N / Nᶠ
    du[13] = SD - s0 + s1 * r
    du[14] = AD - γ0 - (1/(1-γ)) * SD
    du[15] = AP - p0 - p1 * (AD / AS) # AP - p0 - p1 * AD + p2 * AS
    du[16] = AS - AQ * (α + gₐ)
  end
end

