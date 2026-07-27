module CoreTests

using Test
using PKAssetPrices

const BaseModels = PKAssetPrices.BaseModels

@testset "Core types and modules" begin
    equation = BaseModels.Equation(:x, :(a + 1))
    @test equation.lhs == :x
    @test equation.rhs == :(a + 1)
    @test string(equation) == "x == a + 1"
    @test occursin("x == a + 1", sprint(show, equation))
    @test occursin("x == a + 1", sprint(show, MIME("text/plain"), equation))

    @test PKAssetPrices.Static.PQ.model isa BaseModels.AbstractModel
    @test PKAssetPrices.Dynamic.WorkingModel.model isa BaseModels.AbstractModel
    @test isdefined(PKAssetPrices, :Dashboard)
    @test isdefined(PKAssetPrices, :DynamicPlotting)
    @test isdefined(PKAssetPrices, :StaticPlotting)
end

@testset "Dashboard registry" begin
    models = PKAssetPrices.dashboard_models()
    expected = Set(["PQ", "PQA", "PQC", "PQCr", "PQCrDIFF"])
    @test Set(keys(models)) == expected
    @test all(model -> model isa PKAssetPrices.Static.Parametrization, values(models))
    @test models["PQ"] === PKAssetPrices.Static.PQ
    @test models["PQA"] === PKAssetPrices.Static.PQA
end

end
