
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

Base.@kwdef struct SimplePKModel <: AbstractPKModel
  params::SimplePKModelParams = SimplePKModelParams()
  u0::SVector{12,Float64} = zeros(SVector{12})
end

function get_matrix_form(p::SimplePKModelParams)
    (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = p
    
    # Matrix A (12×12) - variable order: [Y, ND, D, r, i, P, dL, dM, dR, W, N, U]
    A = [
        1    -1    -c     0     0     0     0     0     0     0     0     0;
        -b    1     0     0     0     0     0     0     0     0     0     0;
        0     0     1    d_1    0     0     0     0     0     0     0     0;
        0     0     0     0     1   -i_1    0     0     0     0     0     0;
        0     0     0     1  -(1+m)   0     0     0     0     0     0     0;
        0     0    -c     0     0     0     1     0     0     0     0     0;
        0     0     0     0     0     0    -1     1     0     0     0     0;
        0     0     0     0     0     0     0    -k     1     0     0     0;
        0     0     0     0     0     1     0     0     0 -(1+n)*a 0     0;
        0     0     0     0     0     0     0     0     0     1     0     h;
        -a    0     0     0     0     0     0     0     0     0     1     0;
        0     0     0     0     0     0     0     0     0     0  1/Nᶠ    1
    ]
    
    # Vector b
    b_vec = [0.0, 0.0, d_0, i_0, 0.0, 0.0, 0.0, 0.0, 0.0, W_0, 0.0, 1.0]
    
    return A, b_vec
end



function get_nulls(model::SimplePKModel)
  return function simple_model(u, p::SimplePKModelParams)
    (; b, c, d_0, d_1, i_0, i_1, m, k, n, W_0, h, a, Nᶠ) = p
    Y, ND, D, r, i, P, dL, dM, dR, W, N, U = u
    StaticArrays.SA[
     Y - ND - c * D,
     ND - b * Y,
     D - d_0 + d_1 * r,
     i - i_0 - i_1 * P,
     r - (1 + m) * i,
     dL - c * D,
     dM - dL,
     dR - k * dM,
     P - (1 + n) * a * W,
     W - W_0 + h * U,
     N - a * Y,
     U - 1 + N / Nᶠ]
  end
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
