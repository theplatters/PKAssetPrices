# AP influences AS with improved curves and (maybe) an endogenous alpha – this seems to sometimes give a plausible result in the dahsboard but the solver starts making remarks in the terminal...
PQA = @model begin

    @variables  begin
        Y = "Output"
        ND = "Non debt-financed demand"
        D = "debt-financed demand"
        i = "policy rate"
        r = "interest rate"
        P = "price level"
        dL = "change in loans"
        dM = "change in money"
        dR = "change in reserves"
        W = "wage level"
        N = "employment"
        U = "unemployment rate"
        SD = "speculative financed debt"
        AD = "Asset demand"
        AP = "Asset price"
        AS = "Asset supply"
        α = "Asset supply turnover"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c = 0.8, "credit rationing"
        d0 = 5.0, "autonomous credit financed demand"
        d1 = 8.0, "max discretonary credit demand when r=0"
        i0 = 0.01, "autonomous policy rate"
        i1 = 0.05, "inflation infuced policy rate"
        m = 0.15, "bank markup"
        k = 0.3, "reserve share"
        n = 0.15, "firm markup"
        W0 = 2.0, "autonomous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α₀ = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD / AP
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α₀ / 2 * (1 + AP))
        AMD(AP) = (p1 * ((s0 - r * s1) / (AP * (1 - γ)) + γ0)) / AP
    end


    @balances begin
        @sheet Private begin
            @asset deposits = dM
            @liability loans = dL
        end

        @sheet Banks begin
            @asset loans = dL
            @asset reserves = dR
            @liability deposits = dM
            @liability central_bank_credit = dR
        end

        @sheet CentralBank begin
            @asset central_bank_credit = dR
            @liability reserves = dR
        end
    end

end


# here we bring in the connection ot the real economy
PQCA = @model begin

    @variables  begin
        Y = "Output"
        ND = "Non debt-financed demand"
        D = "debt-financed demand"
        c = "credit rationing"
        i = "policy rate"
        r = "interest rate"
        P = "price level"
        dL = "change in loans"
        dM = "change in money"
        dR = "change in reserves"
        W = "wage level"
        N = "employment"
        U = "unemployment rate"
        SD = "speculative financed debt"
        AD = "Asset demand"
        AP = "Asset price"
        AS = "Asset supply"
        α = "Asset supply turnover"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c₀ = 0.8, "autonomuous credit rationing"
        c₁ = 0.1, "speculative induced credit rationing"
        d0 = 5.0, "autonomous credit financed demand"
        d1 = 8.0, "max discretonary credit demand when r=0"
        i0 = 0.01, "autonomous policy rate"
        i1 = 0.05, "inflation infuced policy rate"
        m = 0.15, "bank markup"
        k = 0.3, "reserve share"
        n = 0.15, "firm markup"
        W0 = 2.0, "autonomous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α₀ = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
        α₀ = 0.1, "turnover 2"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD / AP
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        c == c₀ - c₁ * AD
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α)
        AMD(AP) = (p1 * ((s0 - r * s1) / (AP * (1 - γ)) + γ0)) / AP
    end


    @balances begin
        @sheet Private begin
            @asset deposits = dM
            @liability loans = dL
        end

        @sheet Banks begin
            @asset loans = dL
            @asset reserves = dR
            @liability deposits = dM
            @liability central_bank_credit = dR
        end

        @sheet CentralBank begin
            @asset central_bank_credit = dR
            @liability reserves = dR
        end
    end

end

# here we also let AssetPrices influence r, but this creates instability...

PQCrA = @model begin

    @variables  begin
        Y = "Output"
        ND = "Non debt-financed demand"
        D = "debt-financed demand"
        c = "credit rationing"
        i = "policy rate"
        r = "interest rate"
        P = "price level"
        dL = "change in loans"
        dM = "change in money"
        dR = "change in reserves"
        W = "wage level"
        N = "employment"
        U = "unemployment rate"
        SD = "speculative financed debt"
        AD = "Asset demand"
        AP = "Asset price"
        AS = "Asset supply"
        α = "Asset supply turnover"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c₀ = 0.8, "autonomuous credit rationing"
        c₁ = 0.1, "speculative induced credit rationing"
        d0 = 5.0, "autonomous credit financed demand"
        d1 = 8.0, "max discretonary credit demand when r=0"
        i0 = 0.01, "autonomous policy rate"
        i1 = 0.05, "inflation infuced policy rate"
        i2 = 0.01, "asset price induced policy rate"
        m = 0.15, "bank markup"
        k = 0.3, "reserve share"
        n = 0.15, "firm markup"
        W0 = 2.0, "autonomous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α₀ = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P + i2 * AP
        r == (1 + m) * i
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD / AP
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        c == c₀ - c₁ * SD
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = 1 / (1 - b) * (d0 - d1 * r) * (c₀ - c₁ * s0 + c₁ * s1 * r)
        IR(Y) = 1 / (2 * AQ * Nᶠ * (gₐ + α) * (-1 + γ)) * (
            2 * AQ * (1 + m) * (
                i0 * Nᶠ +
                    a * i1 * (1 + n) * (-h * Nᶠ + Nᶠ * W0 + a * h * Y)
            ) * (gₐ + α) * (-1 + γ)
                +
                i2 * (1 + m) * Nᶠ * p1 * (
                i2 * (1 + m) * s1 + (-1 + γ) * γ0
            )
                -
                sqrt(
                (
                    i2^2 * (1 + m)^2 * Nᶠ * p1 * (
                        -4 * AQ * (
                            Nᶠ * (
                                s0 - (1 + m) * s1 * (i0 - a * i1 * (1 + n) * (h - W0))
                            )
                                - a^2 * h * i1 * (1 + m) * (1 + n) * s1 * Y
                        ) * (gₐ + α) * (-1 + γ)
                            +
                            Nᶠ * p1 * (
                            i2 * (1 + m) * s1 + (-1 + γ) * γ0
                        )^2
                    )
                ) / (-1 + γ)^2
            )
                +
                γ * sqrt(
                (
                    i2^2 * (1 + m)^2 * Nᶠ * p1 * (
                        -4 * AQ * (
                            Nᶠ * (
                                s0 - (1 + m) * s1 * (i0 - a * i1 * (1 + n) * (h - W0))
                            )
                                - a^2 * h * i1 * (1 + m) * (1 + n) * s1 * Y
                        ) * (gₐ + α) * (-1 + γ)
                            +
                            Nᶠ * p1 * (
                            i2 * (1 + m) * s1 + (-1 + γ) * γ0
                        )^2
                    )
                ) / (-1 + γ)^2
            )
        )
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α)
        AMD(AP) = (p1 * ((s0 - ((1 + m) * (i0 + i1 * ((1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))) + i2 * AP)) * s1) / (AP * (1 - γ)) + γ0)) / AP

    end


    @balances begin
        @sheet Private begin
            @asset deposits = dM
            @liability loans = dL
        end

        @sheet Banks begin
            @asset loans = dL
            @asset reserves = dR
            @liability deposits = dM
            @liability central_bank_credit = dR
        end

        @sheet CentralBank begin
            @asset central_bank_credit = dR
            @liability reserves = dR
        end
    end

end

# here we try different interest rates as dicussed. this does roughly what it should, the net effect is quite small. also it is not that stable.

PQCrDIFFA = @model begin

    @variables  begin
        Y = "Output"
        ND = "Non debt-financed demand"
        D = "debt-financed demand"
        c = "credit rationing"
        i = "policy rate"
        r = "interest rate"
        P = "price level"
        dL = "change in loans"
        dM = "change in money"
        dR = "change in reserves"
        W = "wage level"
        N = "employment"
        U = "unemployment rate"
        SD = "speculative financed debt"
        AD = "Asset demand"
        AP = "Asset price"
        AS = "Asset supply"
        α = "Asset supply turnover"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c₀ = 0.8, "autonomuous credit rationing"
        c₁ = 0.1, "speculative induced credit rationing"
        d0 = 5.0, "autonomous credit financed demand"
        d1 = 8.0, "max discretonary credit demand when r=0"
        i0 = 0.01, "autonomous policy rate"
        i1 = 0.05, "inflation infuced policy rate"
        iAP = 2, "Penalty for financing speculative assets"
        m = 0.15, "bank markup"
        k = 0.3, "reserve share"
        n = 0.15, "firm markup"
        W0 = 2.0, "autonomous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        α₀ = 0.1, "turnover 2"
        γ = 0.5, "turnover asset selling"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r * iAP
        AD == γ0 + (1 / (1 - γ)) * SD / AP
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        c == c₀ - c₁ * SD
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α)
        AMD(AP) = (p1 * ((s0 - r * s1) / (AP * (1 - γ)) + γ0)) / AP
    end

    notebooks / Compare - template.ipynb
    @balances begin
        @sheet Private begin
            @asset deposits = dM
            @liability loans = dL
        end

        @sheet Banks begin
            @asset loans = dL
            @asset reserves = dR
            @liability deposits = dM
            @liability central_bank_credit = dR
        end

        @sheet CentralBank begin
            @asset central_bank_credit = dR
            @liability reserves = dR
        end
    end

end
