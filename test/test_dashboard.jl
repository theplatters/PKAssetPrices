module DashboardTests

using Test
using PKAssetPrices
using Dash

const Dashboard = PKAssetPrices.Dashboard
const S = PKAssetPrices.Static

@testset "Dashboard application" begin
    models = PKAssetPrices.dashboard_models()
    dynamic_models = PKAssetPrices.dashboard_dynamic_models()
    app = Dashboard.get_app(models, dynamic_models)
    @test app !== nothing
    @test app.layout isa Dash.Component
    @test_nowarn Dashboard.register_callbacks!(app, models, dynamic_models)
end

@testset "Dynamic dashboard workspace" begin
    models = PKAssetPrices.dashboard_dynamic_models()
    base = models["Working model"]
    names = Dashboard.dynamic_parameter_names(base)
    first_parameter = Symbol(first(names))
    new_value = base.params[first_parameter] + 0.05

    configured = Dashboard.dynamic_parametrization_with_values(
        base,
        [first(names)],
        [new_value],
    )
    @test configured.params[first_parameter] == new_value
    @test base.params[first_parameter] != new_value

    short_model = Dashboard.dynamic_parametrization_with_horizon(base, 6)
    @test length(short_model.model.time.grid) == 6
    @test length(base.model.time.grid) > 6

    empty!(Dashboard.DYNAMIC_SOLVE_CACHE)
    first_solution = Dashboard.solve_dynamic_cached(short_model)
    second_solution = Dashboard.solve_dynamic_cached(short_model)
    @test first_solution === second_solution
    @test all(length(path) == 6 for path in values(first_solution.paths))

    selected = Dashboard.default_dynamic_variables(short_model)
    @test Dashboard.dynamic_explore(models) isa Dash.Component
    @test Dashboard.dynamic_path_component(first_solution, Symbol(first(selected)), 1) isa Dash.Component
    @test Dashboard.dynamic_endpoint_table(first_solution, Symbol.(selected)) isa Dash.Component
    @test Dashboard.dynamic_solution_component(first_solution, selected) isa Dash.Component

    @test Dashboard.dynamic_shock_row(base, 1) isa Dash.Component
    shock = Dashboard.dynamic_shocks_from_rows(
        base, [first(names), :unknown, first(names)], [0.0, 0.0, 4.0],
        [nothing, 2.0, 6.0], [new_value, 1.0, new_value + 0.1])
    @test length(shock) == 2
    @test shock[1].until === nothing
    @test all(occursin("dashboard", item.source) for item in shock)
    @test Dashboard.dynamic_shocks_from_rows(base, [first(names)], [NaN], [1.0], [1.0]) ==
        PKAssetPrices.Dynamic.Shock[]

    long_shock = Dashboard.dynamic_shocks_from_rows(
        base, [first(names)], [last(base.model.time.grid) - 1], [nothing], [new_value])
    shocked = PKAssetPrices.Dynamic.set_shocks(base, long_shock)
    truncated_shocked = Dashboard.dynamic_parametrization_with_horizon(shocked, 6)
    @test truncated_shocked.shocks == shocked.shocks
    value_shocked = Dashboard.dynamic_parametrization_with_values(
        shocked, [first(names)], [new_value + 0.2])
    @test value_shocked.shocks == shocked.shocks
    @test value_shocked.shocks !== shocked.shocks
    @test all(isapprox(path[end], first_solution.paths[var][end]) for (var, path) in
        Dashboard.solve_dynamic_cached(truncated_shocked).paths if haskey(first_solution.paths, var))

    # Rows are filtered against the full base grid, not the selected horizon.
    full_last = last(base.model.time.grid)
    filtered = Dashboard.dynamic_shocks_from_rows(
        base, [first(names), first(names), first(names), "unknown"],
        [0.0, full_last + 1, 0.0, 0.0],
        ["", nothing, "", nothing], [1.0, 2.0, 1.0, 3.0])
    @test length(filtered) == 1
    @test filtered[1].until === nothing
    @test isempty(Dashboard.dynamic_shocks_from_rows(
        base, [first(names)], [2.0], [1.0], [new_value]))
    @test length(Dashboard.dynamic_shocks_from_rows(
        base, [first(names), first(names)], [0.0], [nothing, nothing], [new_value, new_value])) == 1

    # The shock set is part of the dynamic cache key, while equal reconstructed
    # values still reuse the same entry.
    empty!(Dashboard.DYNAMIC_SOLVE_CACHE)
    s1 = PKAssetPrices.Dynamic.Shock(param=first_parameter, from=0, value=new_value,
        source="cache")
    s2 = PKAssetPrices.Dynamic.Shock(param=first_parameter, from=0, value=new_value + 0.1,
        source="cache")
    p1 = PKAssetPrices.Dynamic.set_shocks(base, [s1])
    p2 = PKAssetPrices.Dynamic.set_shocks(base, [s2])
    @test Dashboard.solve_dynamic_cached(p1) !== Dashboard.solve_dynamic_cached(p2)
    @test length(Dashboard.DYNAMIC_SOLVE_CACHE) == 2
    equivalent = PKAssetPrices.Dynamic.set_shocks(base, [deepcopy(s1)])
    @test Dashboard.solve_dynamic_cached(equivalent) === Dashboard.solve_dynamic_cached(p1)
end

@testset "Dashboard solve cache" begin
    empty!(Dashboard.SOLVE_CACHE)
    first_solution = Dashboard.solve_cached(S.Baseline)
    second_solution = Dashboard.solve_cached(S.Baseline)
    @test first_solution === second_solution
    @test length(Dashboard.SOLVE_CACHE) == 1
end

@testset "Dashboard model configuration" begin
    models = PKAssetPrices.dashboard_models()
    @test first(Dashboard.ordered_model_names(models)) == "Baseline"
    @test Dashboard.parameter_names(S.Baseline) == string.(S.Baseline.model.parameters)

    parameter_name = first(Dashboard.parameter_names(S.Baseline))
    parameter = Symbol(parameter_name)
    new_value = S.Baseline.params[parameter] + 0.5
    configured = Dashboard.parametrization_with_values(
        S.Baseline,
        [parameter_name],
        [new_value],
    )
    @test configured.params[parameter] == new_value
    @test S.Baseline.params[parameter] != new_value
    @test Dashboard.parametrization_with_values(S.Baseline, [parameter_name], Any[nothing]) === S.Baseline
end

@testset "Dashboard components" begin
    models = PKAssetPrices.dashboard_models()
    solution = PKAssetPrices.solve_model(S.Baseline)
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

    uneven_sheet = S.BalanceSheetFilled(:test_sector, [:cash => 1.0], Pair{Symbol, Float64}[])
    @test Dashboard.table_from_balance_sheet(uneven_sheet) isa Dash.Component

    layout = Dashboard.get_layout(
        title = "Test",
        xaxis_title = "x",
        yaxis_title = "y",
        x_annotation = 1.0,
        y_annotation = 2.0,
        annotation_text = "point",
    )
    @test layout["title"]["text"] == "Test"
    @test only(layout["annotations"])["x"] == 1.0
end

end
