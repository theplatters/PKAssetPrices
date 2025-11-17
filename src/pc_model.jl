
Base.@kwdef struct PCModelParams
	θ::Float64 = 0.7
	λ₀::Float64 = 0.1
	λ₁::Float64 = 0.1
	λ₂::Float64 = 0.1
	α₁::Float64 = 0.1
	α₂::Float64 = 0.2
	r₋::Float64 = 0.03
	r::Float64 = 0.03
	Bₕ₋::Float64 = 5
	Hs₋::Float64 = 5
	Bcb₋::Float64 = 5
  V₋::Float64 = 10.0
  Bₛ₋::Float64 = 5
end

Base.@kwdef struct PCModel <: AbstractPKModel
	params::PCModelParams = PCModelParams()
	u0::SVector{11, Float64} = zeros(SVector{11})
end

function get_nulls(model::PCModel)
	return function simple_model(u, p::PCModelParams)
		(;
			θ, λ₀, λ₁, λ₂, α₁, α₂, r₋, Bₕ₋, Hs₋, Bcb₋, r,V₋, Bₛ₋
		) = p
		Y, YD, C, G, T, V, Hₕ, Hₛ, Bₕ,Bₛ, Bcb = u
		StaticArrays.SA[
			Y-C-G,
			YD-Y+T-r₋*Bₕ₋,
			T-θ*(Y+r₋*Bₕ₋),
			V-V₋-YD+C,
			C-α₁*YD-α₂*V₋,
			Hₕ-V+Bₕ,
			Bₕ-V*(λ₀+λ₁*r)+λ₂*YD,
			Hₕ-V*((1-λ₀)-λ₁*r)-λ₂*YD,
			Bₛ-(G+r₋*Bₛ₋)+(T+r₋*Bcb₋)+Bₛ₋,
			Hₛ-(Bcb-Bcb₋)-Hs₋,
			Bcb-Bₛ+Bₕ,
		]
	end
end
