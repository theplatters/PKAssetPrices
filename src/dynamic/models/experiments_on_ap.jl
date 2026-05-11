DynQconAPLevelChange = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.2, "speculative debt induced by interest"
        s2 = 0.2, "speculative debt induced by interest"
        s3 = 0.2, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.76
        AP = 1.0
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] - s2 * AP[t] + s3 * (AP - AP[t - 1]) / AP[t - 1]
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end

DynQconAPChange = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.5, "speculative debt induced by interest"
        s2 = 0.5, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.0
        AP = [1.0, 1.0]
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] + s2 * (AP - AP[t - 1]) / AP[t - 1]
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end

DynQoldAPLevelChange = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.5, "speculative debt induced by interest"
        s2 = 0.5, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.76
        AP = [1.0, 1.0]
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] + s2 * (AP[t - 1] - AP[t - 2]) / AP[t - 2]
        AD == γ0 + (1 / (1 - γ)) * SD / AP[t - 1]
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end

DynQoldAPChange = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.5, "speculative debt induced by interest"
        s2 = 0.5, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.76
        AP = [1.0, 1.0]
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] + s2 * (AP[t - 1] - AP[t - 2]) / AP[t - 2]
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end

DynQconAPLevelChange2 = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.5, "speculative debt induced by interest"
        s2 = 0.5, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.76
        AP = [1.0, 1.0]
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] + s2 * (AP[t] - AP[t - 1]) / AP[t - 1]
        AD == γ0 + (1 / (1 - γ)) * SD / AP
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end


DynQodlAPLevelChange2 = @model begin
    @time 0.0:1.0:100.0

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
        AQ = "Asset amount"
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
        s0 = 1.0, "autonomous speculative debt"
        s1 = 0.5, "speculative debt induced by interest"
        s2 = 0.2, "speculative debt induced by interest"
        s3 = 0.2, "speculative debt induced by interest"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
    end

    @init begin
        AQ = 6.0
        P = 1.06
        AP = [1.0, 1.0]
        r = 0.11
    end

    @equations begin
        i[t] == i0 + i1 * P[t - 1]
        r == (1 + m) * i
        D == d0 - d1 * r
        Y == ND + c * D
        ND == b * Y
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD[t] == s0 - s1 * r[t - 1] - s2 * AP[t - 1] + s3 * (AP[t - 1] - AP[t - 2]) / AP[t - 2]
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == α * AQ
        AQ == (1 + gₐ) * AQ[t - 1]
    end
end
