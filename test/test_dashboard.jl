module DashboardTests

using Test
using PKAssetPrices
using Dash

const Dashboard = PKAssetPrices.Dashboard
const S = PKAssetPrices.Static

@testset "Dashboard application" begin
    models = PKAssetPrices.dashboard_models()
    app = Dashboard.get_app(models)
    @test app !== nothing
    @test app.layout isa Dash.Component
    @test_nowarn Dashboard.register_callbacks!(app, models)
end

@testset "Dashboard solve cache" begin
    empty!(Dashboard.SOLVE_CACHE)
    first_solution = Dashboard.solve_cached(S.PQ)
    second_solution = Dashboard.solve_cached(S.PQ)
    @test first_solution === second_solution
    @test length(Dashboard.SOLVE_CACHE) == 1
end

@testset "Dashboard components" begin
    models = PKAssetPrices.dashboard_models()
    solution = PKAssetPrices.solve_model(S.PQ)
    labels = ["Baseline", "Baseline copy"]
    solutions = [solution, solution]

    @test Dashboard.model_explore(models) isa Dash.Component
    @test Dashboard.comparisons(models) isa Dash.Component
    @test Dashboard.variable_component(solution) isa Dash.Component
    @test Dashboard.balance_sheet_component(solution) isa Dash.Component
    @test Dashboard.is_ir_component(solution) isa Dash.Component
    @test Dashboard.ad_as_curve_component(solution) isa Dash.Component
    @test Dashboard.solution_component(solution) isa Dash.Component
    @test Dashboard.variable_comparison_table(solutions, labels) isa Dash.Component
    @test Dashboard.balance_sheet_comparison_table(solutions, labels) isa Dash.Component
    @test Dashboard.curves_grid(solutions, labels) isa Dash.Component
    @test Dashboard.comparison_results(solutions, labels) isa Dash.Component

    layout = Dashboard.get_layout(
        title = "Test",
        xaxis_title = "x",
        yaxis_title = "y",
        x_annotation = 1.0,
        y_annotation = 2.0,
        annotatation_text = "point",
    )
    @test layout["title"]["text"] == "Test"
    @test only(layout["annotations"])["x"] == 1.0
end

end
