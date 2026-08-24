module PlottingTests

using Test
using PKAssetPrices
using CairoMakie
using Printf

const S = PKAssetPrices.Static
const D = PKAssetPrices.Dynamic
const SP = PKAssetPrices.StaticPlotting
const DP = PKAssetPrices.DynamicPlotting

@testset "Static plotting" begin
    solution = PKAssetPrices.solve_model(S.Baseline)
    figure = Figure()
    axis = Axis(figure[1, 1])
    @test SP.plot_is_lm(solution, axis) === axis
    @test length(axis.scene.plots) == 6
    @test axis.limits[] == ((4.0, 10.0), (0.06, 0.15))
    @test axis.yticks[][2] == ["6%", "8%", "10%", "12%", "14%"]
    is_ir_lines = filter(plot -> plot isa Lines, axis.scene.plots)
    @test is_ir_lines[1].color[] == RGBAf(SP.IS_COLOR)
    @test is_ir_lines[1].linewidth[] == 3.0
    @test is_ir_lines[2].color[] == RGBAf(SP.IR_COLOR)
    @test is_ir_lines[3].color[] == RGBAf(SP.IS_COLOR, 0.38f0)
    @test is_ir_lines[3].linewidth[] == 2.0
    @test is_ir_lines[3].linestyle[] == Float32[0, 3, 6]
    @test "IR (lower i₀)" in vcat([plot.text[] for plot in axis.scene.plots if plot isa Makie.Text]...)
    lower_rate_model = SP.lower_autonomous_policy_rate(solution.model)
    @test lower_rate_model.params[:i0] == 0.0 * solution.model.params[:i0]
    @test solution.model.params[:i0] == S.Baseline.params[:i0]
    @test_throws ArgumentError SP.lower_autonomous_policy_rate(solution.model; factor=1.0)
    balance_figure = Figure()
    balance_axis = Axis(balance_figure[1, 1])
    @test SP.plot_balance_sheets(solution, balance_axis) === balance_axis
    @test SP.reserve_ratio(solution) ≈ solution.variables[:dR] / solution.variables[:dM]
    @test SP.total_loans(solution) ≈ solution.variables[:dL]
    @test SP.risk_indicator(solution) ≈ solution.variables[:SD] / solution.variables[:dL]
    @test SP.risk_indicator(PKAssetPrices.solve_model(S.SimplePK)) == 0.0
    @test !any(content -> content isa Legend, balance_figure.content)
    asset_axis = Axis(figure[1, 3])
    @test SP.plot_asset_market(solution, asset_axis) === asset_axis
    @test length(asset_axis.scene.plots) == 6
    asset_lines = filter(plot -> plot isa Lines, asset_axis.scene.plots)
    @test extrema(point[2] for point in asset_lines[1][1][]) == SP.ASSET_X_LIMITS
    ad_as_axis = Axis(figure[2, 1])
    @test SP.plot_ad_as(solution, ad_as_axis) === ad_as_axis
    @test length(ad_as_axis.scene.plots) == 6
    @test ad_as_axis.limits[] == ((5.0, 9.0), (1.2, 2.2))
    @test asset_axis.limits[] == ((0.6, 1.3), (0.7, 1.3))
    ad_lines = filter(plot -> plot isa Lines, ad_as_axis.scene.plots)
    @test ad_lines[1].color[] == RGBAf(SP.IS_COLOR)
    @test ad_lines[2].color[] == RGBAf(SP.IR_COLOR)
    @test ad_lines[3].linestyle[] == Float32[0, 3, 6]
    @test Set(vcat([plot.text[] for plot in ad_as_axis.scene.plots if plot isa Makie.Text]...)) ==
        Set(["AD", "AD (lower i₀)", "AS"])
    balance_text = [plot.text[][1] for plot in balance_axis.scene.plots if
        plot isa Makie.Text && length(plot.text[]) == 1]
    @test only(balance_text) == join([
        @sprintf("Total Debt / GDP: %.2f", solution.variables[:dL] / solution.variables[:Y]),
        @sprintf("Speculative debt / Total Debt: %.2f", solution.variables[:SD] / solution.variables[:dL]),
    ], '\n')
    annotation_plot = only(plot for plot in balance_axis.scene.plots if
        plot isa Makie.Text && length(plot.text[]) == 1)
    @test annotation_plot.color[] == RGBAf(0, 0, 0, 0.75f0)

    data = SP.balance_sheet_plot_data(solution)
    @test length(data.positions) == sum(
        length(sheet.assets) + length(sheet.liabilities) for sheet in solution.sheets
    )
    @test length(data.tick_positions) == 2 * length(solution.sheets)
    @test length(unique(data.positions)) == 2 * length(solution.sheets)
    @test all(data.values[data.sides .== :asset] .>= 0)
    @test all(data.values[data.sides .== :liability] .>= 0)
    @test all(data.totals .>= 0)
    @test data.actor_labels == ["Private Sector", "Banks", "Central Bank"]
    @test data.actor_positions ≈ [1.5, 4.5, 7.5]
    @test data.tick_labels == repeat(["Assets", "Liabilities"], length(solution.sheets))
    segment_colors = SP.balance_sheet_segment_colors(data.instruments, data.sides)
    @test SP.ASSET_COLOR == RGBf(0.5, 0, 0.5)
    @test SP.LIABILITY_COLOR == RGBf(1, 0.5, 0)
    @test all(segment_colors[data.sides .== :asset] .== SP.ASSET_COLOR)
    @test all(segment_colors[data.sides .== :liability] .== SP.LIABILITY_COLOR)
    @test "Central Bank · Central Bank Credit" in data.labels
    @test extrema(SP.equilibrium_range(0.0)) == (-1.0, 1.0)
    @test extrema(SP.equilibrium_range(-2.0)) == (-4.0, -1.0)

    for model in (S.Baseline, S.PQC, S.PQCr, S.PQCrDIFF, S.FirmsRation)
        model_solution = PKAssetPrices.solve_model(model)
        curves = S.eval_curve(model_solution)
        @test curves.IS ≈ model_solution.variables[:Y]
        @test curves.IR ≈ model_solution.variables[:r]
        @test curves.ADc ≈ model_solution.variables[:Y]
        @test curves.ASc ≈ model_solution.variables[:P]
        @test curves.AMD ≈ curves.AMS
    end

    simple_solution = PKAssetPrices.solve_model(S.SimplePK)
    simple_panel = SP.panel(simple_solution; size=(900, 700))
    simple_ad_axis = only(content for content in simple_panel.content if
        content isa Axis && occursin("Output and Inflation Dynamics", string(content.title[])))
    @test first(simple_ad_axis.limits[][1]) <= simple_solution.variables[:Y] <= last(simple_ad_axis.limits[][1])
    @test first(simple_ad_axis.limits[][2]) <= simple_solution.variables[:P] <= last(simple_ad_axis.limits[][2])

    asset_models = (S.Baseline, S.PQC, S.PQCr, S.PQCrDIFF, S.FirmsRation)
    asset_panels = map(asset_models) do model
        model_solution = PKAssetPrices.solve_model(model)
        (solution=model_solution,
         figure=SP.panel(model_solution, SP.AssetMarketPanel(); size=(900, 700)))
    end
    for entry in asset_panels
        model_solution = entry.solution
        figure = entry.figure
        ad_axis = only(content for content in figure.content if
            content isa Axis && occursin("Output and Inflation Dynamics", string(content.title[])))
        asset_axis_for_model = only(content for content in figure.content if
            content isa Axis && occursin("Financial Market Dynamics", string(content.title[])))
        curves = S.eval_curve(model_solution)
        @test first(ad_axis.limits[][1]) <= model_solution.variables[:Y] <= last(ad_axis.limits[][1])
        @test first(ad_axis.limits[][2]) <= model_solution.variables[:P] <= last(ad_axis.limits[][2])
        @test first(asset_axis_for_model.limits[][1]) <= curves.AMD <= last(asset_axis_for_model.limits[][1])
        @test first(asset_axis_for_model.limits[][2]) <= model_solution.variables[:AP] <= last(asset_axis_for_model.limits[][2])
    end
    firms_panel = only(asset_panels[i].figure for i in eachindex(asset_models) if
        asset_models[i] === S.FirmsRation)
    firms_ad_axis = only(content for content in firms_panel.content if
        content isa Axis && occursin("Output and Inflation Dynamics", string(content.title[])))
    @test first(firms_ad_axis.limits[][1]) < 5.0
    pqcrdiff_entry = only(asset_panels[i] for i in eachindex(asset_models) if
        asset_models[i] === S.PQCrDIFF)
    pqcrdiff_asset_axis = only(content for content in pqcrdiff_entry.figure.content if
        content isa Axis && occursin("Financial Market Dynamics", string(content.title[])))
    @test first(pqcrdiff_asset_axis.limits[][2]) <= pqcrdiff_entry.solution.variables[:AP] <= last(pqcrdiff_asset_axis.limits[][2])
    @test first(pqcrdiff_asset_axis.limits[][1]) <= S.eval_curve(pqcrdiff_entry.solution).AMD <= last(pqcrdiff_asset_axis.limits[][1])

    panel = SP.panel(solution; size = (1200, 800))
    @test panel isa Figure
    @test size(panel.scene) == (1200, 800)
    @test count(content -> content isa Axis, panel.content) == 3
    curve_axis = only(
        content for content in panel.content
        if content isa Axis && occursin("Goods Market Dynamics", string(content.title[]))
    )
    @test curve_axis.xlabel[] == "Output Y"
    @test curve_axis.ylabel[] == "interest rate r"
    aggregate_axis = only(
        content for content in panel.content
        if content isa Axis && occursin("Output and Inflation Dynamics", string(content.title[]))
    )
    @test aggregate_axis.ylabel[] == "Price Level P"

    asset_panel = SP.panel(solution, SP.AssetMarketPanel(); size = (1200, 1000))
    @test asset_panel isa Figure
    @test size(asset_panel.scene) == (1200, 1000)
    @test count(content -> content isa Axis, asset_panel.content) == 4
    asset_market_axis = only(
        content for content in asset_panel.content
        if content isa Axis && occursin("Financial Market Dynamics", string(content.title[]))
    )
    @test asset_market_axis.xlabel[] == "Base-price-equivalent quantity"
    @test asset_market_axis.ylabel[] == "Asset Price AP"
    @test count(content -> content isa Axis &&
        occursin("Sector Balance Sheets", string(content.title[])), asset_panel.content) == 1

    titled_panel = SP.panel(
        PKAssetPrices.solve_model(S.Baseline),
        SP.AssetMarketPanel();
        size = (1200, 1000),
        title = "Linear speculative-debt variant",
    )
    @test titled_panel isa Figure

    baseline = PKAssetPrices.solve_model(S.SimplePK)
    lower_simple_rate = SP.lower_autonomous_policy_rate(baseline.model)
    @test lower_simple_rate.params[:i₀] == 0.0 * baseline.model.params[:i₀]
    @test_throws ArgumentError SP.panel(baseline, SP.AssetMarketPanel())
    @test size(SP.panel(solution).scene) == (1400, 1000)
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
