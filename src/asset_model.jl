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
  ASold::Float64= 0.2
  ACreated::Float64 = 0.01
  p0::Float64 = 1.0
  p1::Float64 = 1.0
  p2::Float64 = 1.0
  α0::Float64 = 1.0
  α1::Float64 = 1.0
  s0::Float64 = 1.0
  s1::Float64 = 1.0
end

Base.@kwdef struct AssetPKModel <: AbstractPKModel
  params::AssetPKModelParams = AssetPKModelParams()
  u0::Vector = zeros(16)
end

function get_nulls(model::AssetPKModel)
  function nulls!(du, u, p::AssetPKModelParams)
    (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ, α0,α1, s0, s1, p0,p1,p2, Asold, Acreated) = p
    Y, ND, D, r, i, P, dL, dM, dR, W, N, U, SD, AD, AP, AS = u
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
    du[14] = AD - α0 + α1 * SD
    du[15] = AP - p0 - p1 * AD + p2 * AS
    du[16] = ASold + ACreated
  end
end

function get_matrix_form(p::AssetPKModelParams)
    (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ, α0, α1, s0, s1, p0, p1, p2, Asold, Acreated, s0, s1) = p
    
    # Matrix A (16×16) - variable order: [Y, ND, D, r, i, P, dL, dM, dR, W, N, U, SD, AD, AP, AS]
    A = [
        1    -1    -c     0     0     0     0     0     0     0     0     0     0     0     0     0;
        -b    1     0     0     0     0     0     0     0     0     0     0     0     0     0     0;
        0     0     1    d_1    0     0     0     0     0     0     0     0     0     0     0     0;
        0     0     0     0     1   -i_1    0     0     0     0     0     0     0     0     0     0;
        0     0     0     1  -(1+m)   0     0     0     0     0     0     0     0     0     0     0;
        0     0    -c     0     0     0     1     0     0     0     0     0    -1     0     0     0;
        0     0     0     0     0     0    -1     1     0     0     0     0     0     0     0     0;
        0     0     0     0     0     0     0    -k     1     0     0     0     0     0     0     0;
        0     0     0     0     0     1     0     0     0 -(1+n)*a 0     0     0     0     0     0;
        0     0     0     0     0     0     0     0     0     1     0     h     0     0     0     0;
        -a    0     0     0     0     0     0     0     0     0     1     0     0     0     0     0;
        0     0     0     0     0     0     0     0     0     0  1/Nᶠ    1     0     0     0     0;
        0     0     0    s1    0     0     0     0     0     0     0     0     1     0     0     0;
        0     0     0     0     0     0     0     0     0     0     0     0   -α1     1     0     0;
        0     0     0     0     0     0     0     0     0     0     0     0     0   -p1     1    p2;
        0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     1
    ]
    
    # Vector b
    b_vec = [0.0, 0.0, d_0, i_0, 0.0, 0.0, 0.0, 0.0, 0.0, W_0, 0.0, 1.0, s0, α0, p0, -(Asold + Acreated)]
    
    return A, b_vec
end

