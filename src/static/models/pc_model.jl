# as far as i got it this one does not play any role – what is it again?
PC = @model begin
    @parameters begin
        θ = 0.7, "idk"
        λ₀ = 0.1, "idk"
        λ₁ = 0.1, "idk"
        λ₂ = 0.1, "idk"
        α₁ = 0.1, "idk"
        α₂ = 0.2, "idk"
        r₋ = 0.03, "idk"
        r = 0.03, "idk"
        Bₕ₋ = 5.0, "idk"
        Hs₋ = 5.0, "idk"
        Bcb₋ = 5.0, "idk"
        V₋ = 10.0, "idk"
        Bₛ₋ = 5.0, "idk"
    end

    @variables begin
        Y = "Ouput"
        YD = "Debt financed output"
        C = "Consumption"
        G = "Government spending"
        T = "Taxes"
        V = "Wealth"
        Hₕ = "Household"
        Hₛ = "idk"
        Bₕ = "idk"
        Bₛ = "idk"
        Bcb = "idk"
    end


    @equations begin
        Y == C + G
        YD == Y - T + r₋ * Bₕ₋
        T == θ * (Y + r₋ * Bₕ₋)
        V == V₋ + YD - C
        C == α₁ * YD + α₂ * V₋
        Hₕ == V + Bₕ
        Bₕ == V * (λ₀ + λ₁ * r) - λ₂ * YD
        Hₕ == V * ((1 - λ₀) - λ₁ * r) + λ₂ * YD
        Bₛ == (G + r₋ * Bₛ₋) - (T + r₋ * Bcb₋) - Bₛ₋
        Hₛ == (Bcb - Bcb₋) + Hs₋
        Bcb == Bₛ - Bₕ
    end
end
