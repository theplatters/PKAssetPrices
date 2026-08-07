
#AD and AS are quantities
AssetPKSimple = @model begin

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
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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


#AD and AS are given in euros, AS is chosen with post equilibrium prices (AP)
AssetPKSimple2 = @model begin

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
        α = 0.1, "Held assets being sold again"
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
        AD == γ0 + (1 / (1 - γ)) * SD 
        AP == p1 * (AD / AS)
        AS == AP * AQ * (α + gₐ)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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

#AD and AS are given in euros, AS is with pre equilibrium prices (AP)
AssetPKSimple3 = @model begin

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
        α = 0.1, "Held assets being sold again"
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
        AD == γ0 + (1 / (1 - γ)) * SD 
        AP == p1 * (AD / AS)
        AS == p1 * AQ * (α + gₐ)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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

# AP influences AS
AssetPKSimple4 = @model begin

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
        dL == c * D + AP * SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD
        AP == p1 * (AD / AS)
        AS == AP * AQ * (α + gₐ)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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

# AP influences AS
AssetPKSimple5 = @model begin

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
        AS ==  AQ * (α + gₐ)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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

# AssetPK has endogenous alpha and exogenous c
# AssetPK2 als makes c endognous, which makes it impossible to draw curves (have there been any other problems with this?)
# ExoAlpha gas endogenous c and exogenous alpha; the remainder are variations, where CBsense has a central bank that is sensitive to asset prices, and DualInterest additionally has a policy rate that is sensitive to asset prices. Both of these are still work in progress, and not fully tested yet.
# Another, maybe unnoticed difference relates to the equations for SD and AD, where I have correct the latter (from p1 to AP), but SD still lacks the second term (s2 * (AP - 1)) found in all other models. One should maybe check what difference this makes, and whether it should be added to AssetPK as well.

# we probably have to recheck all the specifications for "curves", because this is case-sensitive and we mostly used copy-paste to generate this ;-) ??

AssetPK = @model begin

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
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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

AssetPKSDcompare = @model begin

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
        SD == s0 - s1 * r + s2 * (AP - 1)
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
        α == α₀ / 2 * (1 + AP)
    end

    @curves begin
        IS(r) = (1 / (1 - b)) * (c * (d0 - d1 * r))
        IR(Y) = (1 + m) * (i0 + i1 * (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ)))
        ADc(P) = (1 / (1 - b)) * (c * (d0 - d1 * ((1 + m) * (i0 + i1 * P))))
        ASc(Y) = (1 + n) * a * (W0 - h * (1 - (a * Y) / Nᶠ))
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


AssetPK2 = @model begin

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
        Nᶠ = 6.0, "total labour supply"
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
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
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

ExoAlpha = @model begin

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
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomuous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        s2 = 1.0, "speculative debt induced by asset price"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
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
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
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

CBsense = @model begin

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
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomuous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        s2 = 1.0, "speculative debt induced by asset price"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d_0 - d_1 * r
        i == i_0 + i_1 * P
        r == (1 + m) * i * AP
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W_0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r + s2 * (AP - 1)
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
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

DualInterest = @model begin

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
        Nᶠ = 6.0, "total labour supply"
        p1 = 1.0, "base asset price"
        s0 = 0.5, "autonomuous speculative debt"
        s1 = 1.0, "speculative debt induced by interest"
        s2 = 1.0, "speculative debt induced by asset price"
        γ0 = 0.0, "autonomous asset demand"
        γ = 0.5, "turnover asset selling"
        α = 0.1, "turnover 2"
        gₐ = 0.03, "rate of assets being created"
        AQ = 6.0, "asset amount"
    end

    @equations begin
        Y == ND + c * D
        ND == b * Y
        D == d_0 - d_1 * r / AP
        i == i_0 + i_1 * P
        r == (1 + m) * i * AP
        dL == c * D + SD
        dM == dL
        dR == k * dM
        P == (1 + n) * a * W
        W == W_0 - h * U
        N == a * Y
        U == 1 - N / Nᶠ
        SD == s0 - s1 * r + s2 * (AP - 1)
        AD == γ0 + (1 / (1 - γ)) * SD / AP # SD is in euros, but should be a quantity(?)
        AP == p1 * (AD / AS)
        AS == AQ * (α + gₐ)
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
