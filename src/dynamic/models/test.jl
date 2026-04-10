using PKAssetPrices.Dynamic: DynamicModel, DiscreteTime, DynamicParametrization, solve_model, @model

test = @model begin
    @time 0.0:1.0:100.0

    @variables begin
        Y = "output"
        C = "consumption"
        K = "capital"
        B = "debt"
    end

    @parameters begin
        α = 0.3, "share"
        β = ones(101), "time varying"  # allowed; used by your solver build_context
        δ = 0.2
        I = 3.0, "Investment"
    end

    @init begin
        K = 3.0
        B = 2.0
    end

    @equations begin
        Y == C + β * I + K[t]
        K[t] == K[t - 1] + I - δ * K[t - 1]
        C == 0.2 * Y
    end
end
Revise.retry()

test.model.equations[2]
solve_model(test).paths
