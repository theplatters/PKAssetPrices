@model SimplePK begin
    @variables begin
        Y = "Output"
        ND = "Non debt-financed demand"
        D = "debt-financed demand"
        r = "interest rate"
        i = "policy rate"
        P = "price level"
        dL = "change in loans"
        dM = "change in money"
        dR = "change in reserves"
        W = "wage level"
        N = "employment"
        U = "unemployment rate"
    end

    @parameters begin
        b = 0.5, "consumption rate"
        c = 0.8, "credit rationing"
        d₀ = 5.0, "autonomuous  credit financed demand"
        d₁ = 8, "induced credit financed demand"
        i₀ = 0.01, "autonomuous policy rate"
        i₁ = 0.05, "inflation infuced policy rate"
        m = 0.15, "policy rate markup"
        k = 0.3, "resere share"
        n = 0.15, "firm markup"
        W₀ = 2.0, "autonomuous wages"
        h = 0.8, "bargaining power?"
        a = 0.8, "production induced employment "
        Nᶠ = 12.0, "total labour supply"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d₀ - d₁ * r
        r == (1 + m) * i
        i == i₀ + i₁ * P
        dL == c * D
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W₀ - h * U
        N == a * Y
        U == 1 - N / Nᶠ
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
            @liability central_bank_money = dR
        end

        @sheet CentralBank begin
            @asset reserves = dR
            @liability money_supply = dM
        end
    end
end
