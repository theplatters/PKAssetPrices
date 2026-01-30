using PKAssetPrices.Dynamic: DynamicModel, DiscreteTime, DynamicParametrization, solve_model, @model
using PKAssetPrices

Revise.retry()
test = @model begin
    @time 0.0:1.0:100.0

    @flows begin
        Y = "output"
        C = "consumption"
    end

    @stocks begin
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
        Y == C + I
        K[t] == K[t - 1] + I - δ * K[t - 1]
    end
end

test.model.equations[2]
solve_model(test).paths
