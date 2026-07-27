module DynamicTests

using Test
using PKAssetPrices
using PKAssetPrices.Dynamic: @model, @scenario, DiscreteTime, DynamicModel,
    DynamicParametrization, DynamicSolution

const D = PKAssetPrices.Dynamic

LagOneFixture = @model begin
    @time 1.0:1.0:3.0
    @variables begin
        x = "state"
    end
    @parameters begin
        drift = 0.5, "period increment"
    end
    @init begin
        x = 1.0
    end
    @equations begin
        x[t] == x[t - 1] + drift
    end
end

LagTwoFixture = @model begin
    @time 1.0:1.0:3.0
    @variables begin
        x = "state"
    end
    @parameters begin
        offset = 0.0, "period offset"
    end
    @init begin
        x = [1.0, 2.0]
    end
    @equations begin
        x[t] == x[t - 2] + offset
    end
end

LagOneScenario = @scenario LagOneFixture begin
    drift = 1.0
end

@testset "Dynamic model DSL" begin
    model = LagOneFixture.model
    @test model.time.grid == [1.0, 2.0, 3.0]
    @test only(model.variables).name == :x
    @test only(model.params).name == :drift
    @test only(model.equations).lhs == :(x[t])
    @test D._time_lag(:t) == 0
    @test D._time_lag(:(t - 1)) == 1
    @test D._time_lag(:(t - 2)) == 2
    @test isnothing(D._time_lag(:(t - 3)))
    @test_throws ErrorException D.check_expr(:(x[t - 3]))
end

@testset "Dynamic contexts and evaluation" begin
    paths = Dict(:x => [1.5, 2.0, 2.5])
    first_context = D.build_context(LagOneFixture, 1, paths)
    second_context = D.build_context(LagOneFixture, 2, paths)
    third_context = D.build_context(LagOneFixture, 3, paths)
    @test first_context[Symbol("x[t - 1]")] == 1.0
    @test first_context[Symbol("x[t - 2]")] == 0.0
    @test second_context[Symbol("x[t - 1]")] == 1.5
    @test second_context[Symbol("x[t - 2]")] == 1.0
    @test third_context[Symbol("x[t - 2]")] == 1.5
    @test D.eval_model(LagOneFixture, Dict(:x => 2.0), Dict(:x => 1.5)) ≈ [2.0]

    initialized = D.init_paths(LagOneFixture.model, 4, Float64)
    @test keys(initialized) == Set([:x])
    @test length(initialized[:x]) == 4
end

@testset "Dynamic solve and scenario" begin
    lag_one = PKAssetPrices.solve_model(LagOneFixture)
    lag_two = PKAssetPrices.solve_model(LagTwoFixture)
    scenario = PKAssetPrices.solve_model(LagOneScenario)
    @test lag_one isa DynamicSolution
    @test lag_one.paths[:x] ≈ [1.5, 2.0, 2.5]
    @test lag_two.paths[:x] ≈ [1.0, 2.0, 1.0]
    @test scenario.paths[:x] ≈ [2.0, 3.0, 4.0]
    @test LagOneFixture.params[:drift] == 0.5
end

@testset "Optimization parameter mapping" begin
    original = D.DynαQCr
    values = collect(0.1:0.1:1.4)
    updated = D.update_params(original, values)
    expected_names = (:c₀, :c₁, :i0, :i1, :i2, :s0, :s1, :s2, :γ, :α₀, :d0, :d1, :gₐ, :m)
    @test [updated.params[name] for name in expected_names] ≈ values
    @test original.params[:c₀] != updated.params[:c₀]
    @test updated.model === original.model
    @test_throws BoundsError D.update_params(original, [1.0])
end

end
