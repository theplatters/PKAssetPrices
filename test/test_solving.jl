module SolvingTests

using Test
using PKAssetPrices
using SciMLBase
import NonlinearSolve as NLS
using PKAssetPrices.Static: @model, @scenario, Model, Parametrization
using PKAssetPrices.Dynamic: DynamicParametrization, DynamicModel, DiscreteTime

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic

StaticInitFixture = @model begin
    @variables begin
        x = "x"
        y = "y"
    end
    @parameters begin
        a = 2.0
    end
    @init begin
        x = -3.0
    end
    @equations begin
        x == a
        y == x + 1
    end
end

ParameterlessFixture = @model begin
    @variables begin
        x = "x"
    end
    @equations begin
        x == 2
    end
end

DynamicSolveFixture = D.@model begin
    @time 1.0:1.0:2.0
    @variables begin
        x = "x"
    end
    @parameters begin
        a = 2.0
    end
    @init begin
        x = [1.0]
    end
    @equations begin
        x[t] == a
    end
end

StaticScenario = @scenario StaticInitFixture begin
    a = 4.0
end
DynamicScenario = D.@scenario DynamicSolveFixture begin
    a = 3.0
end

function expand_static(ex)
    macroexpand(S, ex)
end

function eval_static_scenario(ex)
    Core.eval(@__MODULE__, macroexpand(S, ex))
end

function eval_dynamic_scenario(ex)
    Core.eval(@__MODULE__, macroexpand(D, ex))
end

@testset "static initialization and solver metadata" begin
    @test StaticInitFixture.u0 == [-3.0, 1.0]
    @test StaticScenario.u0 == StaticInitFixture.u0
    StaticScenario.u0[1] = 99.0
    @test StaticInitFixture.u0[1] == -3.0

    solution = PKAssetPrices.solve_model(StaticInitFixture; u0=[10.0, 11.0])
    @test solution isa S.Solution
    @test solution.retcode isa SciMLBase.ReturnCode.T
    @test solution.max_residual isa Float64
    @test solution.max_residual < 1e-8
    @test StaticInitFixture.u0 == [-3.0, 1.0]
    @test solution.x ≈ 2.0
    @test occursin("retcode", sprint(show, solution; context=:compact => true))
    @test occursin("Max residual", sprint(show, solution))
    parameterless_solution = PKAssetPrices.solve_model(ParameterlessFixture)
    @test parameterless_solution.x ≈ 2.0
    @test isempty(ParameterlessFixture.params)
    @test parameterless_solution.max_residual < 1e-8
    option_solution = PKAssetPrices.solve_model(
        StaticInitFixture; alg=NLS.NewtonRaphson(), abstol=1e-10, reltol=1e-10,
        maxiters=100)
    @test SciMLBase.successful_retcode(option_solution.retcode)
    @test_throws r"u0 length" PKAssetPrices.solve_model(StaticInitFixture; u0=[1.0])

    @test_throws r"@init.*numeric literal" expand_static(
        :(@model begin
            @variables begin
                x = "x"
            end
            @init begin
                x = a + 1
            end
            @equations begin
                x == 1
            end
        end))
    @test_throws r"duplicate.*@init" expand_static(
        :(@model begin
            @variables begin
                x = "x"
            end
            @init begin
                x = 1.0
                x = 2.0
            end
            @equations begin
                x == 1
            end
        end))
    @test_throws r"@init names.*z" expand_static(
        :(@model begin
            @variables begin
                x = "x"
            end
            @init begin
                z = 1.0
            end
            @equations begin
                x == 1
            end
        end))

    @test_throws r"Duplicate @scenario parameter.*a" eval_static_scenario(
        :(@scenario StaticInitFixture begin
            a = 3.0
            a = 4.0
        end))
    @test_throws r"missing.*not declared" eval_static_scenario(
        :(@scenario StaticInitFixture begin
            missing = 3.0
        end))
end

@testset "solver options, failures, and dynamic scenario isolation" begin
    @test DynamicScenario.u0 == DynamicSolveFixture.u0
    DynamicScenario.u0[1] = 77.0
    DynamicScenario.init[:x][1] = 88.0
    @test DynamicSolveFixture.u0[1] == 1.0
    @test DynamicSolveFixture.init[:x][1] == 1.0
    @test_throws r"Duplicate @scenario parameter.*a" eval_dynamic_scenario(
        :(@scenario DynamicSolveFixture begin
            a = 3.0
            a = 4.0
        end))
    @test_throws r"missing.*not declared" eval_dynamic_scenario(
        :(@scenario DynamicSolveFixture begin
            missing = 3.0
        end))

    dynamic_solution = PKAssetPrices.solve_model(DynamicSolveFixture)
    @test dynamic_solution isa D.DynamicSolution
    @test length(dynamic_solution.retcodes) == 2
    @test length(dynamic_solution.max_residuals) == 2
    @test all(iszero, dynamic_solution.max_residuals)
    @test all(SciMLBase.successful_retcode, dynamic_solution.retcodes)
    dynamic_options = PKAssetPrices.solve_model(
        DynamicSolveFixture; alg=NLS.NewtonRaphson(), abstol=1e-10, reltol=1e-10,
        maxiters=100)
    @test all(SciMLBase.successful_retcode, dynamic_options.retcodes)

    static_flagged = @test_logs (:warn,) PKAssetPrices.solve_model(
        StaticInitFixture; maxiters=0, strict=false)
    @test static_flagged.retcode == SciMLBase.ReturnCode.MaxIters
    @test static_flagged.max_residual > 0
    @test_throws r"Static.*retcode.*max residual" PKAssetPrices.solve_model(
        StaticInitFixture; maxiters=0)

    dynamic_flagged = @test_logs (:warn,) (:warn,) PKAssetPrices.solve_model(
        DynamicSolveFixture; maxiters=0, strict=false)
    @test length(dynamic_flagged.retcodes) == 2
    @test all(==(SciMLBase.ReturnCode.MaxIters), dynamic_flagged.retcodes)
    @test all(>(0), dynamic_flagged.max_residuals)
    @test_throws r"Dynamic.*period 1.*retcode.*max residual" PKAssetPrices.solve_model(
        DynamicSolveFixture; maxiters=0)
end

end
