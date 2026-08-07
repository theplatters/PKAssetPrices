module ModelSmokeTests

using Test
using PKAssetPrices

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic

const STATIC_MODELS = (
    :Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation,
    :PQA, :PQCA, :PQCrA, :PQCrDIFFA, :PC, :SimplePK,
)

const DYNAMIC_MODELS = (
    :DynαQCr, :DynαQC, :DynαQ, :DynQ, :Dynα, :WorkingModel,
    :DynQconAPLevelChange, :DynQconAPChange,
    :DynQoldAPLevelChange, :DynQoldAPChange,
    :DynQconAPLevelChange2, :DynQodlAPLevelChange2,
)

@testset "All static models solve" begin
    for name in STATIC_MODELS
        parametrization = getproperty(S, name)
        solution = PKAssetPrices.solve_model(parametrization)
        u = [solution.variables[var] for var in parametrization.model.variables]
        residual = parametrization.model.nulls(u, (; parametrization.params...))

        @testset "$name" begin
            @test all(isfinite, values(solution.variables))
            @test maximum(abs, residual) < 1.0e-8
            @test length(solution.variables) == length(parametrization.model.variables)
            @test all(sheet -> S.assets(sheet) ≈ S.liabilities(sheet), solution.sheets)
            curves = S.eval_curve(solution)
            @test isnothing(curves) || all(isfinite, values(curves))
        end
    end
end

@testset "Linear nominal asset-market models" begin
    names = (:Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation)

    for name in names
        parametrization = getproperty(S, name)
        solution = PKAssetPrices.solve_model(parametrization)
        variables = solution.variables
        curves = S.eval_curve(solution)
        speculative_rate_multiplier = 1 +
            parametrization.params[:differential_rate_channel] *
            (parametrization.params[:iAP] - 1)

        @testset "$name" begin
            @test variables[:SD] ≈
                parametrization.params[:s0] -
                parametrization.params[:s1] * speculative_rate_multiplier * variables[:r] -
                parametrization.params[:s2] * (variables[:AP] - 1)
            @test variables[:AD] ≈
                parametrization.params[:γ0] + variables[:SD] / (1 - parametrization.params[:γ])
            @test variables[:dL] ≈ variables[:c] * variables[:D] + variables[:SD]
            @test curves.IS ≈ variables[:Y] atol = 1.0e-8
            @test curves.IR ≈ variables[:r] atol = 1.0e-8
            @test curves.ADc ≈ variables[:Y] atol = 1.0e-8
            @test curves.ASc ≈ variables[:P] atol = 1.0e-8
            @test curves.AMD ≈ curves.AMS atol = 1.0e-8
        end
    end
end

@testset "Baseline asset-market calibration" begin
    params = S.Baseline.params
    solution = PKAssetPrices.solve_model(S.Baseline)

    @test (params[:s0], params[:s1], params[:s2]) ==
        (0.836089551258839, 4.0, 0.2)
    @test solution.variables[:SD] ≈ 0.38865823446839143
    @test solution.variables[:AD] ≈ 0.7773164689367829
    @test solution.variables[:AP] ≈ 0.996559575559978
end

@testset "Static IS and IR curves meet at equilibrium" begin
    for name in (:SimplePK, :Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation)
        solution = PKAssetPrices.solve_model(getproperty(S, name))
        curves = S.eval_curve(solution)

        @testset "$name" begin
            @test curves.IS ≈ solution.variables[:Y] atol = 1.0e-8
            @test curves.IR ≈ solution.variables[:r] atol = 1.0e-8
        end
    end
end

@testset "Static asset-market curves meet at equilibrium" begin
    for name in (:Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation)
        solution = PKAssetPrices.solve_model(getproperty(S, name))
        curves = S.eval_curve(solution)

        @testset "$name" begin
            @test curves.AMD ≈ curves.AMS atol = 1.0e-8
        end
    end
end

@testset "Static ADc and ASc curves meet at equilibrium" begin
    for name in (:SimplePK, :Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation)
        solution = PKAssetPrices.solve_model(getproperty(S, name))
        curves = S.eval_curve(solution)

        @testset "$name" begin
            @test curves.ADc ≈ solution.variables[:Y] atol = 1.0e-8
            @test curves.ASc ≈ solution.variables[:P] atol = 1.0e-8
        end
    end
end

@testset "Speculative debt enters bank loans" begin
    for name in (:PQCr, :PQCrDIFF)
        solution = PKAssetPrices.solve_model(getproperty(S, name))
        variables = solution.variables

        @testset "$name" begin
            @test variables[:dL] ≈ variables[:c] * variables[:D] + variables[:SD]
        end
    end
end

@testset "All dynamic models solve" begin
    for name in DYNAMIC_MODELS
        parametrization = getproperty(D, name)
        solution = PKAssetPrices.solve_model(parametrization)
        max_residual = 0.0
        for t in eachindex(parametrization.model.time.grid)
            context = D.build_context(parametrization, t, solution.paths)
            u = [solution.paths[var.name][t] for var in parametrization.model.variables]
            max_residual = max(max_residual, maximum(abs, parametrization.model.nulls(u, context)))
        end

        @testset "$name" begin
            @test all(path -> all(isfinite, path), values(solution.paths))
            @test all(path -> length(path) == length(parametrization.model.time.grid), values(solution.paths))
            @test max_residual < 1.0e-8
        end
    end
end

end
