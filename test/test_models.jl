module ModelSmokeTests

using Test
using PKAssetPrices

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic

const STATIC_MODELS = (
    :Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation,
    :PQA, :PQCA, :PQCrA, :PQCrDIFFA, :SimplePK,
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
            @test variables[:AE] ≈
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
    @test solution.variables[:AE] ≈ 0.7773164689367829
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

# Step-4 trajectory snapshot regression oracle.
# Baseline values captured from current code. Paths are indexed by the
# 1-based period (index into the solved path vector). WorkingModel spans only
# periods 1, 10, 50; all other models also include period 100.
const STEP4_COMMON_Y = Dict(
    1 => 6.55744,
    10 => 6.566017914629413,
    50 => 6.566017914628955,
    100 => 6.566017914628955,
)
const STEP4_COMMON_R = Dict(
    1 => 0.1127,
    10 => 0.11202985041957712,
    50 => 0.11202985041961297,
    100 => 0.11202985041961297,
)
const STEP4_EXPERIMENT_R = Dict(
    1 => 0.1127,
    10 => 0.11202985041957712,
    50 => 0.11202985041961298,
    100 => 0.11202985041961298,
)

const STEP4_SNAPSHOT = Dict(
    :DynαQCr => Dict(
        :Y  => Dict(1 => 7.1641513818729, 10 => 7.647584064818865, 50 => 7.759957513192481, 100 => 7.816763860653236),
        :AP => Dict(1 => 1.7311163317481895, 10 => 1.5853270840447868, 50 => 0.9593334814217601, 100 => 0.5029367489946903),
        :r  => Dict(1 => 0.011490804247011264, 10 => 0.011370494952336746, 50 => 0.01136055080528153, 100 => 0.011351667291560041),
    ),
    :DynαQC => Dict(
        :Y  => Dict(1 => 3.1065872000000003, 10 => 4.969375873570952, 50 => 4.3646373676777115, 100 => 2.9063959722069237),
        :AP => Dict(1 => 2.0484951194924936, 10 => 1.8071440703038992, 50 => 1.0453044536203329, 100 => 0.5255476072773304),
        :r  => Dict(1 => 0.1127, 10 => 0.10308372921322619, 50 => 0.0997191164463837, 100 => 0.09161155263099743),
    ),
    :DynαQ => Dict(
        :Y  => copy(STEP4_COMMON_Y),
        :AP => Dict(1 => 2.0484951194924936, 10 => 1.8051425092949327, 50 => 1.0433006840235497, 100 => 0.5234980666940345),
        :r  => copy(STEP4_COMMON_R),
    ),
    :DynQ => Dict(
        :Y  => copy(STEP4_COMMON_Y),
        :AP => Dict(1 => 2.5088838916691665, 10 => 2.2888003360176814, 50 => 1.0626029633660639, 100 => 0.451103509344627),
        :r  => copy(STEP4_COMMON_R),
    ),
    :Dynα => Dict(
        :Y  => Dict(1 => 6.55744, 10 => 6.5660179146294135, 50 => 6.566017914628954, 100 => 6.566017914628954),
        :AP => Dict(1 => 1.8978545391709687, 10 => 1.8993786654032674, 50 => 1.8993786654034415, 100 => 1.8993786654034415),
        :r  => Dict(1 => 0.1127, 10 => 0.11202985041957712, 50 => 0.11202985041961297, 100 => 0.11202985041961297),
    ),
    :WorkingModel => Dict(
        :Y  => Dict(1 => 6.397401797999999, 10 => 6.1281208447874835, 50 => 6.104428163874871),
        :AP => Dict(1 => 2.5383017613825194, 10 => 1.8425919736188836, 50 => 1.7216039773138463),
        :r  => Dict(1 => 0.07245000000000001, 10 => 0.10954072211881667, 50 => 0.10942811786090577),
    ),
    :DynQconAPLevelChange => Dict(
        :Y  => copy(STEP4_COMMON_Y),
        :AP => Dict(1 => 2.516051779935275, 10 => 1.6142774092998828, 50 => 0.6418636653495553, 100 => 0.1629282305968962),
        :r  => copy(STEP4_EXPERIMENT_R),
    ),
    :DynQconAPChange => Dict(
        :Y  => Dict(1 => 7.1168000000000005, 10 => 6.566017914599495, 50 => 6.566017914628955, 100 => 6.566017914628955),
        :AP => Dict(1 => -2.4371727748691105, 10 => 0.38339339426072566, 50 => 0.003945884235622817, 100 => 1.0434371043080359e-5),
        :r  => Dict(1 => 0.069, 10 => 0.11202985042191452, 50 => 0.11202985041961298, 100 => 0.11202985041961298),
    ),
    :DynQoldAPLevelChange => Dict(
        :Y  => copy(STEP4_COMMON_Y),
        :AP => Dict(1 => 3.053883495145631, 10 => 1.475490711192134, 50 => 0.8376991124001302, 100 => 0.4000897577178795),
        :r  => copy(STEP4_EXPERIMENT_R),
    ),
    :DynQoldAPChange => Dict(
        :Y  => copy(STEP4_COMMON_Y),
        :AP => Dict(1 => 3.053883495145631, 10 => 2.186161534293149, 50 => 0.7066925058510892, 100 => 0.16120154804633866),
        :r  => copy(STEP4_EXPERIMENT_R),
    ),
    :DynQconAPLevelChange2 => Dict(
        :Y  => Dict(1 => 6.55744, 10 => 6.566017914629412, 50 => 6.566017914628954, 100 => 6.566017914628954),
        :AP => Dict(1 => 3.0387649989015055, 10 => 1.4134038426985631, 50 => 1.6364608632175468, 100 => 1.5259656057568316),
        :r  => Dict(1 => 0.1127, 10 => 0.11202985041957712, 50 => 0.11202985041961297, 100 => 0.11202985041961297),
    ),
    :DynQodlAPLevelChange2 => Dict(
        :Y  => Dict(1 => 7.07264, 10 => 6.566017914601858, 50 => 6.566017914628954, 100 => 6.566017914628954),
        :AP => Dict(1 => 2.53830176138252, 10 => 1.840107989193359, 50 => 1.7192323175917037, 100 => 1.5591888413875157),
        :r  => Dict(1 => 0.07245, 10 => 0.11202985042172998, 50 => 0.11202985041961297, 100 => 0.11202985041961297),
    ),
)

@testset "Step-4 trajectory snapshot regression" begin
    for (model_name, var_table) in STEP4_SNAPSHOT
        @testset "$model_name" begin
            parametrization = getproperty(D, model_name)
            solution = PKAssetPrices.solve_model(parametrization)
            for (var, period_table) in var_table
                for (period, expected) in period_table
                    if haskey(solution.paths, var)
                        @test solution.paths[var][period] ≈ expected atol = 1.0e-10
                    end
                end
            end
        end
    end
end

end
