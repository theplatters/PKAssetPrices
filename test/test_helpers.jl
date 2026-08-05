module HelperTests

using Test
using PKAssetPrices
using OrderedCollections
using CairoMakie

const S = PKAssetPrices.Static

@testset "Formatting helpers" begin
    @test S.pad_to([1, 2], 4, 0) == [1, 2, 0, 0]
    @test S.pad_to([1, 2], 1, 0) == [1, 2]
    @test S.title_from_snake("central_bank_credit") == "Central Bank Credit"
    @test S.title_from_snake(:asset_price) == "Asset Price"

    solution = PKAssetPrices.solve_model(S.Baseline)
    @test occursin("Parametrization", sprint(show, solution.model))
    @test occursin("Solution", sprint(show, solution))
    @test occursin("BalanceSheetFilled", sprint(show, first(solution.sheets)))
    @test occursin("Solution(", sprint(show, solution; context = :compact => true))
end

@testset "Balance-sheet totals and rendering" begin
    sheet = S.BalanceSheetFilled(
        :Household,
        [:cash => 1.0, :bonds => 2.0],
        [:equity => 3.0],
    )
    @test S.assets(sheet) == 3.0
    @test S.liabilities(sheet) == 3.0

    html = S.to_html(sheet)
    @test occursin("Cash", html)
    @test occursin("Bonds", html)
    @test occursin("Equity", html)
    @test occursin("3.0", html)
    @test occursin("Bonds", sprint(show, MIME("text/html"), sheet))

    rendered = mktemp() do _, io
        redirect_stdout(io) do
            S.display_sheets([sheet]; compact = false)
        end
        seekstart(io)
        read(io, String)
    end
    @test occursin("Balance sheet 1: Household", rendered)
    @test occursin("Δ (assets - liabilities) = 0.0", rendered)
end

@testset "Real-model helper plots" begin
    baseline = PKAssetPrices.solve_model(S.Baseline)
    changed_params = copy(S.Baseline.params)
    changed_params[:b] = 0.45
    changed = PKAssetPrices.solve_model(S.Parametrization(S.Baseline.model, changed_params, S.Baseline.u0))
    solutions = OrderedDict("Baseline" => baseline, "Changed" => changed)

    sweep = S.eval_curve(baseline, :r, [0.01, 0.02, 0.03], :IS)
    @test length(unique(sweep)) == 3
    @test S.bar_chart(solutions, [:Y, :AP]) isa Figure
    is_ir = S.is_ir_component(baseline)
    @test is_ir isa Figure
    is_ir_axis = only(content for content in is_ir.content if content isa Axis)
    @test is_ir_axis.xlabel[] == "Output (Y)"
    @test is_ir_axis.ylabel[] == "Interest rate (r)"
    @test is_ir_axis.limits[] == ((0.0, 15.0), (0.0, 0.20))
    @test S.ad_as_component(baseline) isa Figure
    @test S.ad_as_comparison_component([baseline, changed], ["Baseline", "Changed"]) isa Figure
end

end
