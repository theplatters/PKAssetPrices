module StaticTests

using Test
using PKAssetPrices
using PKAssetPrices.Static

const S = PKAssetPrices.Static
const Equation = PKAssetPrices.BaseModels.Equation

StaticFixture = @model begin
    @variables begin
        x = "input"
        y = "output"
    end

    @parameters begin
        a = 2.0, "input level"
        b = 3.0, "output offset"
    end

    @equations begin
        y == x + b
        x == a
    end

    @curves begin
        LINE(x) = a * x + b
    end

    @balances begin
        @sheet Household begin
            @asset cash = x
            @liability funding = x
        end
    end
end

DescriptionlessFixture = @model begin
    @variables begin
        x
    end
    @parameters begin
        a = 2.0
    end
    @equations begin
        x == a
    end
end

StaticScenario = @scenario StaticFixture begin
    a = 4.0
end

@testset "Static model DSL" begin
    model = StaticFixture.model
    @test model.variables == [:x, :y]
    @test model.parameters == [:a, :b]
    @test model.variable_descriptions[:y] == "output"
    @test model.parameter_descriptions[:a] == "input level"
    @test getfield.(model.equations, :lhs) == [:x, :y]
    @test only(model.curves).name == :LINE
    @test only(model.balance_sheets).name == :Household
    @test DescriptionlessFixture.params[:a] == 2.0

    invalid = [Equation(:z, 1.0)]
    @test_throws ErrorException S.sort_equations_by_variables!(invalid, [:x])
end

@testset "Static solve and scenario" begin
    solution = PKAssetPrices.solve_model(StaticFixture)
    @test solution isa S.Solution
    @test solution.x ≈ 2.0
    @test solution.y ≈ 5.0
    @test solution.variables[:x] == solution.x
    @test solution.model === StaticFixture
    @test length(solution.sheets) == 1
    @test only(solution.sheets).assets == [:cash => 2.0]
    @test only(solution.sheets).liabilities == [:funding => 2.0]

    scenario_solution = PKAssetPrices.solve_model(StaticScenario)
    @test scenario_solution.x ≈ 4.0
    @test scenario_solution.y ≈ 7.0
    @test StaticFixture.params[:a] == 2.0
    @test StaticScenario.params[:a] == 4.0
end

@testset "Static curve evaluation" begin
    solution = PKAssetPrices.solve_model(StaticFixture)
    @test S.eval_curve(solution).LINE ≈ 7.0
    @test S.eval_curve(StaticFixture, Dict(:x => 5.0, :y => 8.0)).LINE ≈ 13.0
    @test S.eval_curve(solution, :x, [1.0, 2.0, 4.0], :LINE) ≈ [5.0, 7.0, 11.0]
end

@testset "Balance-sheet expression evaluation" begin
    vars = Dict(:x => 2.0)
    params = Dict(:a => 3.0)
    @test S._eval_calc(4, vars, params) == 4.0
    @test S._eval_calc(:x, vars, params) == 2.0
    @test S._eval_calc(:a, vars, params) == 3.0
    @test S._eval_calc(:(x + a), vars, params) == 5.0
    @test_throws ErrorException S._eval_calc(:missing, vars, params)
end

end
