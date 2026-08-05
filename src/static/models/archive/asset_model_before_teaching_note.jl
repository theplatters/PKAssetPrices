# AP influences AS
PQ = @model begin

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
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + SD
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
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α)
        AMD(AP) = ((s0 - r * s1) / (AP * (1 - γ)) + γ0) / AP
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


PQCold = @model begin

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
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + SD
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
# here we bring in the connection ot the real economy
PQC = @model begin

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
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c0 = 0.8, "autonomuous credit rationing"
        c1 = 0.1, "speculative induced credit rationing"
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
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + SD
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
        c == c0 - c1 * AD
    end

    @curves begin
        IS(r) = (d0 - d1 * r) / (1 - b) *
            (
            c0 - c1 / 2 *
                (
                γ0 + sqrt(
                    γ0^2 +
                        4 * (s0 - s1 * r) * AQ * (gₐ + α) /
                        ((1 - γ) * p1)
                )
            )
        )

        IR(Y) = (1 + m) * (i0 + a * i1 * (1 + n) * (W0 + h * (-1 + (a * Y) / Nᶠ)))
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

PQCr = @model begin

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
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c0 = 0.8, "autonomuous credit rationing"
        c1 = 0.1, "speculative induced credit rationing"
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
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P + i2 * AP
        r == (1 + m) * i
        dL == c * D + SD
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
        c == c0 - c1 * AD
    end

    @curves begin
        IS(r) = (d0 - d1 * r) / (1 - b) *
            (
            c0 - c1 / 2 *
                (
                γ0 + sqrt(
                    γ0^2 +
                        4 * (s0 - s1 * r) * AQ * (gₐ + α) /
                        ((1 - γ) * p1)
                )
            )
        )
        IR(Y) = let
            price_level = (1 + n) * a * (W0 - h * (1 - a * Y / Nᶠ))
            base_rate = (1 + m) * (i0 + i1 * price_level)
            feedback = (1 + m) * i2
            supply = AQ * (gₐ + α)
            quadratic = supply / p1
            linear = -γ0 + s1 * feedback / (1 - γ)
            constant = (s1 * base_rate - s0) / (1 - γ)
            asset_price = (-linear + sqrt(linear^2 - 4 * quadratic * constant)) /
                          (2 * quadratic)
            base_rate + feedback * asset_price
        end
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

PQCrDIFF = @model begin

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
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d0 - d1 * r
        i == i0 + i1 * P
        r == (1 + m) * i
        dL == c * D + SD
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
    end

    @curves begin
        IS(r) = (1 / (1 - b)) *
            ((c₀ - c₁ * (s0 - s1 * r * iAP)) * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        AS(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
        AMS(AP) = AQ * (gₐ + α)
        AMD(AP) = (p1 * ((s0 - r * s1 * iAP) / (AP * (1 - γ)) + γ0)) / AP
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
