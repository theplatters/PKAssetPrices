module SFCTests

using Test
using PKAssetPrices
using PKAssetPrices.Dynamic: @model, @scenario, DynamicParametrization, DynamicModel, DiscreteTime
using PKAssetPrices.Static: BalanceSheetFilled

const D = PKAssetPrices.Dynamic
const S = PKAssetPrices.Static

SheetLagFixture = @model begin
    @time 1.0:1.0:4.0
    @variables begin x end
    @parameters begin a = 1.0 end
    @init begin x = [10.0, 20.0, 30.0] end
    @equations begin x[t] == a end
    @balances begin
        @sheet Ledger begin
            @asset total = x[t] + x[t - 3]
            @liability total_liability = x[t] + x[t - 3]
        end
    end
end

SheetLagScenario = @scenario SheetLagFixture begin
    a = 2.0
    @equations begin
        x[t] == a + 1
    end
    @init begin
        x = [1.0, 2.0, 3.0]
    end
end

ThreePeriodHistoryFixture = @model begin
    @time 1.0:1.0:4.0
    @variables begin
        x = "state"
    end
    @parameters begin
        increment = 1.0, "increment"
    end
    @init begin
        x = [1.0, 2.0, 3.0]
    end
    @equations begin
        x[t] == x[t - 3] + increment
    end
end

@testset "Static sheet oracle and accounting" begin
    sol = PKAssetPrices.solve_model(S.Baseline)
    @test sol.sheets == [
        BalanceSheetFilled(:PrivateSector, [:deposits => 3.6716671917828685], [:loans => 3.6716671917828685]),
        BalanceSheetFilled(:Banks, [:loans => 3.6716671917828685, :reserves => 1.1015001575348604], [:deposits => 3.6716671917828685, :central_bank_credit => 1.1015001575348604]),
        BalanceSheetFilled(:CentralBank, [:central_bank_credit => 1.1015001575348604], [:reserves => 1.1015001575348604]),
    ]
    for name in (:Baseline, :PQC, :PQCr, :PQCrDIFF, :FirmsRation, :PQA, :PQCA, :PQCrA, :PQCrDIFFA, :SimplePK)
        @test PKAssetPrices.check_accounting(PKAssetPrices.solve_model(getproperty(S, name))).consistent
    end
end

@testset "Dynamic sheets, arbitrary lags, and accounting" begin
    sol = PKAssetPrices.solve_model(SheetLagFixture)
    expected = [
        [BalanceSheetFilled(:Ledger, [:total => 11.0], [:total_liability => 11.0])],
        [BalanceSheetFilled(:Ledger, [:total => 21.0], [:total_liability => 21.0])],
        [BalanceSheetFilled(:Ledger, [:total => 31.0], [:total_liability => 31.0])],
        [BalanceSheetFilled(:Ledger, [:total => 2.0], [:total_liability => 2.0])],
    ]
    @test sol.sheets == expected
    @test D.sheets(sol, 3) == expected[3]
    accounting = D.check_accounting(sol)
    @test accounting.consistent
    @test all(x -> x.consistent, accounting.periods)
    @test D.check_accounting(sol, 2).consistent
end

@testset "Scenario rebuilds balance-sheet closures" begin
    solution = PKAssetPrices.solve_model(SheetLagScenario)
    @test SheetLagScenario isa DynamicParametrization
    @test SheetLagScenario.model !== SheetLagFixture.model
    @test SheetLagScenario.model.sheet_eval !== SheetLagFixture.model.sheet_eval
    @test SheetLagScenario.model.equations[1].rhs == :(a + 1)
    @test solution.paths[:x] == [3.0, 3.0, 3.0, 3.0]
    @test [sheet[1].assets[1].second for sheet in solution.sheets] == [4.0, 5.0, 6.0, 6.0]
end

@testset "Accounting diagnostics and sheet validation" begin
    bad = BalanceSheetFilled(:BadSector, [:asset => 2.0], [:liability => 1.0])
    @test_logs (:warn, r"Accounting inconsistency") begin
        result = PKAssetPrices.ModelCore._accounting_result([bad])
        @test !result.consistent
        @test result.sector_deltas[:BadSector] == 1.0
        @test result.aggregate == 1.0
    end
    @test_throws ErrorException PKAssetPrices.ModelCore._accounting_result([bad]; strict=true)
    duplicate = [bad, BalanceSheetFilled(:BadSector, [:asset => 1.0], [:liability => 1.0])]
    @test_throws r"duplicate BalanceSheetFilled sector_name.*BadSector" PKAssetPrices.ModelCore._accounting_result(duplicate)

    duplicate_source = try
        @eval @model begin
            @time 1.0:1.0:1.0
            @variables begin x end
            @parameters begin a = 1.0 end
            @equations begin x[t] == a end
            @balances begin
                @sheet Same begin @asset a = x[t] end
                @sheet Same begin @liability l = x[t] end
            end
        end
        ""
    catch error
        sprint(showerror, error)
    end
    @test occursin("Duplicate @sheet name Same", duplicate_source)

    message = try
        @eval @model begin
            @time 1.0:1.0:2.0
            @variables begin x end
            @parameters begin a = 1.0 end
            @equations begin x[t] == a end
            @balances begin
                @sheet Broken begin @asset asset = typo + x[t] end
            end
        end
        ""
    catch err
        sprint(showerror, err)
    end
    @test occursin("typo", message)
    @test occursin("Broken", message)
    @test occursin("asset", message)
    @test occursin("Declare", message) || occursin("fix", message)
end

PredeterminedStockFixture = @model begin
    @time 1.0:1.0:4.0
    @variables begin
        x = "state"
        y = "flow"
    end
    @stocks begin
        x = "ignored description"
    end
    @parameters begin
        increment = 1.0
    end
    @init begin
        x = [1.0]
    end
    @equations begin
        x[t] == x[t - 1] + increment
        y[t] == 2x[t] + increment
    end
end

SimultaneousEquivalentFixture = @model begin
    @time 1.0:1.0:4.0
    @variables begin
        x = "state"
        y = "flow"
    end
    @parameters begin
        increment = 1.0
    end
    @init begin
        x = [1.0]
    end
    @equations begin
        x[t] == x[t - 1] + increment
        y[t] == 2x[t] + increment
    end
end

@testset "SFC-style three-period history" begin
    solution = PKAssetPrices.solve_model(ThreePeriodHistoryFixture)
    @test solution.paths[:x] ≈ [2.0, 3.0, 4.0, 3.0]

    context = D.build_context(ThreePeriodHistoryFixture, 1, Dict(:x => [2.0, 3.0, 4.0, 3.0]))
    @test context[PKAssetPrices.ModelCore.lag_key(:x, 3)] == 1.0
end

@testset "Predetermined dynamic stocks" begin
    stock_solution = PKAssetPrices.solve_model(PredeterminedStockFixture)
    simultaneous_solution = PKAssetPrices.solve_model(SimultaneousEquivalentFixture)
    @test PredeterminedStockFixture.model.stocks == [:x]
    @test length(PredeterminedStockFixture.u0) == 1
    @test keys(stock_solution.paths) == keys(simultaneous_solution.paths)
    @test stock_solution.paths[:x] ≈ simultaneous_solution.paths[:x] atol=1e-10
    @test stock_solution.paths[:y] ≈ simultaneous_solution.paths[:y] atol=1e-10
end

@testset "Stock declaration diagnostics" begin
    current_error = try
        @eval @model begin
            @time 1.0:1.0:2.0
            @variables begin x; y end
            @stocks begin x end
            @equations begin x[t] == y[t]; y[t] == x[t] end
        end
        ""
    catch error
        sprint(showerror, error)
    end
    @test occursin("x is marked @stocks but its equation uses current-period values", current_error)
    @test occursin("remove it from @stocks or reformulate", current_error)

    unknown_error = try
        @eval @model begin
            @time 1.0:1.0:2.0
            @variables begin x end
            @stocks begin z = "unknown" end
            @equations begin x[t] == 1 end
        end
        ""
    catch error
        sprint(showerror, error)
    end
    @test occursin("unknown @stocks declaration z", unknown_error)
    @test occursin("variable declared in @variables", unknown_error)
end

end
