@model AssetPK begin

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
        α = "Held asset being sold again"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c = 0.8, "credit rationing"
        d_0 = 5.0, "autonomous credit financed demand"
        d_1 = 8.0, "max discretonary credit demand when r=0"
        i_0 = 0.01, "autonomous policy rate"
        i_1 = 0.05, "inflation infuced policy rate"
        m = 0.15, "bank markup"
        k = 0.3, "reserve share"
        n = 0.15, "firm markup"
        W_0 = 2.0, "autonomous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 12.0, "total labour supply"
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
        D == d_0 - d_1 * r
        i == i_0 + i_1 * P
        r == (1 + m) * i
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W_0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD/p1 # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d₀ - d₁ * r))
        IR(Y) = (1 + m) * (i₀ + i₁ * (1 + n) * a * (W₀ - h * (1 - (a * Y) / Nᶠ)))
        AD(P) = (1 / (1 - b)) * (c * (d₀ - d₁ * ((1 + m) * (i₀ + i₁ * P))))
        AS(Y) = (1 + n) * a * (W₀ - h * (1 - (a * Y) / Nᶠ))
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


@model AssetPK2 begin

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
        SD = "Speculative financed debt"
        AD = "Asset demand"
        AP = "Asset price"
        AS = "Asset supply"
        α = "Held asset being sold again"
        c = "credit rationing"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c₀ = 0.8, "autonomuous credit rationing"
        c₁ = 0.1, "speculative induced credit rationing"
        d_0 = 5.0, "autonomuous  credit financed demand"
        d_1 = 8.0, "induced credit financed demand"
        i_0 = 0.01, "autonomuous policy rate"
        i_1 = 0.05, "inflation infuced policy rate"
        m = 0.15, "policy rate markup"
        k = 0.3, "resere share"
        n = 0.15, "firm markup"
        W_0 = 2.0, "autonomuous wages"
        h = 0.8, "bargaining power" # impact of unemployment on wages
        a = 0.8, "productivity"
        Nᶠ = 12.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomuous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        s2 = 1.0, "speculative debt induced by asset price"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α₀ = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d_0 - d_1 * r
        i == i_0 + i_1 * P
        r == (1 + m) * i
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W_0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r + s2 * (AP - 1)
        AD == γ0 + (1 / (1 - γ)) * SD/p1 # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        α == α₀ / 2 * (1 + AP)
        c == c₀ - c₁ * SD
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
