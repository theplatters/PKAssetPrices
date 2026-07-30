module PlottingTests

using Test
using PKAssetPrices
using CairoMakie

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic
const SP = PKAssetPrices.StaticPlotting
const DP = PKAssetPrices.DynamicPlotting

@testset "Static plotting" begin
    solution = PKAssetPrices.solve_model(S.PQ)
    figure = Figure()
    axis = Axis(figure[1, 1])
    @test SP.plot_is_lm(solution, axis) === axis
    @test axis.limits[] == ((0.0, 0.20), (0.0, 15.0))
    balance_axis = Axis(figure[1, 2])
    @test SP.plot_balance_sheets(solution, balance_axis) === balance_axis
    asset_axis = Axis(figure[1, 3])
    @test SP.plot_asset_market(solution, asset_axis) === asset_axis

    data = SP.balance_sheet_plot_data(solution)
    @test length(data.positions) == sum(
        length(sheet.assets) + length(sheet.liabilities) for sheet in solution.sheets
    )
    @test length(data.tick_positions) == 2 * length(solution.sheets)
    @test length(unique(data.positions)) == 2 * length(solution.sheets)
    @test all(data.values[data.sides .== :asset] .>= 0)
    @test all(data.values[data.sides .== :liability] .>= 0)
    @test all(data.totals .>= 0)
    @test "Central Bank · Central Bank Credit" in data.labels
    @test extrema(SP.equilibrium_range(0.0)) == (-1.0, 1.0)
    @test extrema(SP.equilibrium_range(-2.0)) == (-6.0, -0.4)

    panel = SP.panel(solution; size = (1200, 800))
    @test panel isa Figure
    @test size(panel.scene) == (1200, 800)
    @test count(content -> content isa Axis, panel.content) == 2

    asset_panel = SP.panel(solution, SP.AssetMarketPanel(); size = (1200, 1000))
    @test asset_panel isa Figure
    @test size(asset_panel.scene) == (1200, 1000)
    @test count(content -> content isa Axis, asset_panel.content) == 3
    asset_market_axis = only(
        content for content in asset_panel.content
        if content isa Axis && content.title[] == "Asset market"
    )
    @test asset_market_axis.xlabel[] == "Base-price-equivalent quantity"

    baseline = PKAssetPrices.solve_model(S.SimplePK)
    @test_throws ArgumentError SP.panel(baseline, SP.AssetMarketPanel())
end

@testset "Dynamic plotting" begin
    original_s2 = D.WorkingModel.params[:s2]
    solution = DP.run_dynq_case(model = D.WorkingModel, overwrites = (:s2 => 0.25,))
    initialized = DP.run_dynq_case(model = D.WorkingModel, init_vals = (:AP => [1.0, 1.25],))
    @test solution isa D.DynamicSolution
    @test solution.model.params[:s2] == 0.25
    @test initialized.model.init[:AP] == [1.0, 1.25]
    @test D.WorkingModel.params[:s2] == original_s2
    @test_throws ErrorException DP.run_dynq_case(model = D.WorkingModel, overwrites = (:missing => 1.0,))
    @test_throws ErrorException DP.run_dynq_case(model = D.WorkingModel, init_vals = (:missing => [1.0],))

    cases = [(label = "A", sol = solution), (label = "B", sol = initialized)]
    @test DP.compare_dynq_cases(cases; vars = [:AP], sharey = true) isa Figure
    @test DP.compare_dynq_real_cases(cases; sharey = true) isa Figure
end

end
