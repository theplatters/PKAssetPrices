# Static models with nominal speculative debt and nominal gross asset demand.
# The asset-market equations are linear in nominal flows and the asset price.

SimplePK = @model begin
  @variables begin
    Y = "Output"
    ND = "Non debt-financed demand"
    Iₚ = "Planned investments"
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
    d₀ = 5.0, "autonomous credit-financed demand"
    d₁ = 8, "interest sensitivity of productive credit demand"
    i₀ = 0.01, "autonomous policy rate"
    i₁ = 0.05, "goods-price induced policy rate"
    m = 0.15, "bank markup"
    k = 0.3, "reserve share"
    n = 0.15, "firm markup"
    W₀ = 2.0, "autonomous wages"
    h = 0.8, "bargaining power"
    a = 0.8, "unit labour requirement"
    Nᶠ = 6.0, "total labour supply"
  end

  @equations begin
    Y == ND + c * D
    ND == b * Y
    Iₚ == d₀ - d₁ * r
    D == Iₚ
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
    ADc(P) = (1 / (1 - b)) * (c * (d₀ - d₁ * ((1 + m) * (i₀ + i₁ * P))))
    ASc(Y) = (1 + n) * a * (W₀ - h * (1 - (a * Y) / Nᶠ))
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

AssetModel = @model begin
  @variables begin
    Y = "Output"
    ND = "Non debt-financed demand"
    D = "debt-financed demand"
    Iₚ = "Planned investments"
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
    SD = "nominal speculative debt"
    AD = "nominal gross asset demand"
    AP = "asset price"
    AS = "asset supply"
  end

  @parameters begin
    b = 0.5, "consumption rate"
    c0 = 0.8, "autonomous credit rationing"
    c1 = 0.1, "financial-activity induced credit rationing"
    d0 = 5.0, "autonomous credit financed demand"
    d1 = 8.0, "interest sensitivity of productive credit demand"
    d2 = 1.0, "asset-price sensitivity of planned investment"
    i0 = 0.01, "autonomous policy rate"
    i1 = 0.05, "goods-price induced policy rate"
    i2 = 0.01, "asset-price induced policy rate"
    iAP = 2.0, "penalty for financing speculative assets"
    m = 0.15, "bank markup"
    k = 0.3, "reserve share"
    n = 0.15, "firm markup"
    W0 = 2.0, "autonomous wages"
    h = 0.8, "bargaining power"
    a = 0.8, "unit labour requirement"
    Nᶠ = 6.0, "total labour supply"
    p1 = 1.0, "asset-price scale"
    s0 = 0.5, "autonomous nominal speculative debt"
    s1 = 1.0, "interest sensitivity of speculative debt"
    s2 = 0.2, "asset-price sensitivity of speculative debt"
    γ0 = 0.0, "autonomous nominal asset demand"
    γ = 0.5, "share of asset-sale receipts reinvested"
    α = 0.1, "asset turnover"
    gₐ = 0.03, "rate of assets being created"
    AQ = 6.0, "asset amount"
    credit_ad_channel = 0.0, "activate credit rationing through asset demand"
    credit_sd_channel = 0.0, "activate credit rationing through speculative debt"
    policy_ap_channel = 0.0, "activate the asset-price policy response"
    firms_ap_channel = 0.0, "activate firms' asset-price response"
    differential_rate_channel = 0.0, "activate the speculative-rate penalty"
  end

  @equations begin
    Y == ND + c * D
    ND == b * Y
    D == d0 - d1 * r - firms_ap_channel * d2 * AP
    Iₚ == D
    i == i0 + i1 * P + policy_ap_channel * i2 * AP
    r == (1 + m) * i
    dL == c * D + SD
    dM == dL
    dR == k * dM
    P == (1 + n) * a * W
    W == W0 - h * U
    N == a * Y
    U == 1 - N / Nᶠ
    SD == s0 - s1 * r * (1 + differential_rate_channel * (iAP - 1)) - s2 * AP
    AD == γ0 + SD / (1 - γ)
    AP == p1 * AD / AS
    AS == AQ * (α + gₐ)
    c == c0 - c1 * (credit_ad_channel * AD + credit_sd_channel * SD)
  end

  @curves begin
    IS(r) =
      let
        asset_supply = AQ * (α + gₐ)
        reinvestment_multiplier = 1 / (1 - γ)
        speculative_rate_multiplier =
          1 + differential_rate_channel * (iAP - 1)
        debt_before_price = s0 - s1 * speculative_rate_multiplier * r
        asset_price =
          p1 * (γ0 + reinvestment_multiplier * debt_before_price) /
          (asset_supply + p1 * reinvestment_multiplier * s2)
        speculative_debt = debt_before_price - s2 * asset_price
        asset_demand = asset_supply * asset_price / p1
        credit_rationing = c0 - c1 * (
          credit_ad_channel * asset_demand +
          credit_sd_channel * speculative_debt
        )
        productive_demand = d0 - d1 * r - firms_ap_channel * d2 * asset_price
        credit_rationing * productive_demand / (1 - b)
      end
    IR(Y) =
      let
        price_level = (1 + n) * a * (W0 - h * (1 - a * Y / Nᶠ))
        base_rate = (1 + m) * (i0 + i1 * price_level)
        policy_feedback = (1 + m) * policy_ap_channel * i2
        speculative_rate_multiplier =
          1 + differential_rate_channel * (iAP - 1)
        asset_supply = AQ * (α + gₐ)
        reinvestment_multiplier = 1 / (1 - γ)
        debt_before_price =
          s0 - s1 * speculative_rate_multiplier * base_rate
        total_price_sensitivity =
          s2 + s1 * speculative_rate_multiplier * policy_feedback
        asset_price =
          p1 * (γ0 + reinvestment_multiplier * debt_before_price) /
          (asset_supply + p1 * reinvestment_multiplier * total_price_sensitivity)
        base_rate + policy_feedback * asset_price
      end
    ADc(P) =
      let
        base_rate = (1 + m) * (i0 + i1 * P)
        policy_feedback = (1 + m) * policy_ap_channel * i2
        speculative_rate_multiplier =
          1 + differential_rate_channel * (iAP - 1)
        asset_supply = AQ * (α + gₐ)
        reinvestment_multiplier = 1 / (1 - γ)
        debt_before_price =
          s0 - s1 * speculative_rate_multiplier * base_rate
        total_price_sensitivity =
          s2 + s1 * speculative_rate_multiplier * policy_feedback
        asset_price =
          p1 * (γ0 + reinvestment_multiplier * debt_before_price) /
          (asset_supply + p1 * reinvestment_multiplier * total_price_sensitivity)
        rate = base_rate + policy_feedback * asset_price
        speculative_debt =
          s0 - s1 * speculative_rate_multiplier * rate - s2 * asset_price
        asset_demand = asset_supply * asset_price / p1
        credit_rationing = c0 - c1 * (
          credit_ad_channel * asset_demand +
          credit_sd_channel * speculative_debt
        )
        productive_demand =
          d0 - d1 * rate - firms_ap_channel * d2 * asset_price
        credit_rationing * productive_demand / (1 - b)
      end
    ASc(Y) = (1 + n) * a * (W0 - h * (1 - a * Y / Nᶠ))
    AMS(AP) = AQ * (α + gₐ)
    AMD(AP) =
      let
        price_level = (1 + n) * a * (W0 - h * (1 - a * Y / Nᶠ))
        rate = (1 + m) * (
          i0 + i1 * price_level + policy_ap_channel * i2 * AP
        )
        speculative_rate_multiplier =
          1 + differential_rate_channel * (iAP - 1)
        speculative_debt =
          s0 - s1 * speculative_rate_multiplier * rate - s2 * AP
        nominal_asset_demand = γ0 + speculative_debt / (1 - γ)
        p1 * nominal_asset_demand / AP
      end
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

Baseline = AssetModel

PQC = @scenario AssetModel begin
  credit_ad_channel = 1.0
end

PQCr = @scenario AssetModel begin
  credit_ad_channel = 1.0
  policy_ap_channel = 1.0
end

PQCrDIFF = @scenario AssetModel begin
  credit_sd_channel = 1.0
  differential_rate_channel = 1.0
end

FirmsRation = @scenario AssetModel begin
  firms_ap_channel = 1.0
end
