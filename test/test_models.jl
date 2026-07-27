module ModelSmokeTests

using Test
using PKAssetPrices

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic

const STATIC_MODELS = (
    :PQ, :PQCold, :PQC, :PQCr, :PQCrDIFF,
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
