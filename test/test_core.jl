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

    @test PKAssetPrices.Static.Baseline.model isa BaseModels.AbstractModel
    @test isdefined(PKAssetPrices, :StaticPlotting)
end

end
