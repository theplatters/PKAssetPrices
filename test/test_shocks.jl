module ShockTests
using Test
using PKAssetPrices
using PKAssetPrices.Dynamic: Shock, validate_shocks, @model, @scenario, @shock, DynamicParametrization

const D = PKAssetPrices.Dynamic

error_message(f) = try
    f()
    ""
catch err
    sprint(showerror, err)
end

LagOneShockFixture = @model begin
    @time 1.0:1.0:3.0
    @variables begin x end
    @parameters begin drift = 0.5 end
    @init begin x = 1.0 end
    @equations begin x[t] == x[t - 1] + drift end
end

StockShockFixture = @model begin
    @time 1.0:1.0:3.0
    @variables begin
        x
        y
    end
    @stocks begin x end
    @parameters begin increment = 0.5 end
    @init begin x = 1.0 end
    @equations begin
        x[t] == x[t - 1] + increment
        y[t] == x[t]
    end
end

ScenarioShockBase = @scenario LagOneShockFixture begin
    @shocks begin
        at(2, drift = 1.0)
        during(3:3, drift = 2.0,)
    end
end
ScenarioShockDerived = @scenario ScenarioShockBase begin
    @shocks begin
        at(2, drift = 3.0)
    end
end
ScenarioShockInherited = @scenario ScenarioShockBase begin end
StandaloneShock = @shock LagOneShockFixture begin at(2, drift = 1.0) end
NonoverlapDerived = @scenario ScenarioShockBase begin
    @shocks begin
        during(1:1, drift = 4.0)
    end
end

SheetShockFixture = @model begin
    @time 1.0:1.0:3.0
    @variables begin x end
    @parameters begin asset_value = 1.0 end
    @equations begin x[t] == asset_value end
    @balances begin
        @sheet Ledger begin
            @asset asset = asset_value
            @liability liability = asset_value
        end
    end
end

@testset "scenario and standalone shock macros" begin
    @test [s.source for s in ScenarioShockBase.shocks] ==
        ["at(2, drift = 1.0)", "during(3:3, drift = 2.0)"]
    @test D.solve_model(ScenarioShockBase).paths[:x] == [1.5, 2.5, 4.5]
    @test D.solve_model(ScenarioShockDerived).paths[:x] == [1.5, 4.5, 7.5]
    @test D.solve_model(ScenarioShockInherited).paths[:x] == D.solve_model(ScenarioShockBase).paths[:x]
    @test StandaloneShock.shocks == [ScenarioShockBase.shocks[1]]
    @test ScenarioShockDerived.shocks !== ScenarioShockBase.shocks
    @test ScenarioShockInherited.shocks == ScenarioShockBase.shocks
    @test ScenarioShockInherited.shocks !== ScenarioShockBase.shocks
    @test D.solve_model(NonoverlapDerived).paths[:x] == [5.0, 6.0, 8.0]
    @test length(ScenarioShockBase.shocks) == 2
    @test ScenarioShockBase.init[:x] == [1.0]
    ScenarioShockDerived.init[:x][1] = 99.0
    @test ScenarioShockBase.init[:x] == [1.0]

    bad_assignment = try
        @eval @shock LagOneShockFixture begin drift = 2.0 end
        nothing
    catch err
        sprint(showerror, err)
    end
    @test bad_assignment !== nothing
    @test occursin("@scenario", bad_assignment)
    @test occursin("drift = 2.0", bad_assignment)

    bad_block = error_message(() -> Core.eval(@__MODULE__, :(@shock LagOneShockFixture begin
        @init begin x = 2.0 end
    end)))
    @test_throws Exception Core.eval(@__MODULE__, :(@shock LagOneShockFixture begin
        @init begin x = 2.0 end
    end))
    @test occursin("@init", bad_block) && occursin("@scenario", bad_block)
end

@testset "curated DynαQCr rate-hike trajectory" begin
    p = D.DynαQCrRateHike
    solution = D.solve_model(p)
    expected = Dict(
        1 => (7.1641513818729, 1.7311163317481895, 0.011490804247011264),
        50 => (7.759957513192481, 0.9593334814217601, 0.01136055080528153),
        51 => (7.201337005123275, 0.9472349751908397, 0.05566529274522081),
        52 => (7.182583343447231, 0.933536439344691, 0.057275249433311526),
        101 => (7.231510160946111, 0.495427648956351, 0.05735136776277275),
    )
    for (t, (y, ap, r)) in expected
        @test solution.paths[:Y][t] ≈ y rtol=1e-11
        @test solution.paths[:AP][t] ≈ ap rtol=1e-11
        @test solution.paths[:r][t] ≈ r rtol=1e-11
    end
    max_residual = let z = 0.0
        for t in eachindex(p.model.time.grid)
            context = D.build_context(p, t, solution.paths)
            u = [solution.paths[v.name][t] for v in p.model.variables]
            z = max(z, maximum(abs, p.model.nulls(u, context)))
        end
        z
    end
    @test max_residual < 1e-10
    @test solution.paths[:r][51] > solution.paths[:r][50] + 0.04
end

@testset "shock grammar and plumbing" begin
    parsed = PKAssetPrices.ModelCore.parse_shock_entries(
        :(begin at(1, a=2, b=-3); during(2:4, a=5) end))
    @test length(parsed) == 3
    @test parsed[1].param == :a && parsed[1].until === nothing
    @test parsed[3].from == 2 && parsed[3].until == 4
    @test_throws Exception PKAssetPrices.ModelCore.parse_shock_entries(:(begin at(x, a=1) end))
    @test_throws Exception PKAssetPrices.ModelCore.parse_shock_entries(:(begin during(4:2, a=1) end))
    @test_throws Exception PKAssetPrices.ModelCore.parse_shock_entries(:(begin at(1, a=b) end))

    M = @model begin
        @time 1.0:1.0:4.0
        @variables begin x end
        @parameters begin a = 1.0 end
        @equations begin x[t] == a end
    end
    s = Shock(param=:a, from=1, until=2, value=3, source="test entry")
    @test validate_shocks([s], M) == [s]
    @test_throws Exception validate_shocks([Shock(param=:z, from=1, value=1)], M)
    @test_throws Exception validate_shocks([Shock(param=:a, from=10, value=1)], M)
    @test_throws Exception validate_shocks([s, s], M)
    @test validate_shocks([s, Shock(param=:a, from=2, until=3, value=4)], M) isa Vector
    @test_throws Exception Shock(param=:a, from=2, until=1, value=1)
    @test_throws Exception Shock(param=:a, from=1, value=Inf)
    @test_throws Exception Shock(param=:a, from=true, value=1)

    p = DynamicParametrization(M.model, copy(M.params), M.init, M.u0, [s])
    @test p.shocks == [s]
    @test isempty(DynamicParametrization(M.model, copy(M.params), M.init, M.u0).shocks)
    @test DynamicParametrization(model=M.model, params=Dict(:a=>1.0), init=Dict{Symbol,Float64}(), u0=ones(1), shocks=[s]).shocks == [s]
    @test_throws Exception (@model begin
        @time [2.0, 1.0]
        @variables begin x end
        @parameters begin a = 1.0 end
        @equations begin x[t] == a end
    end)
end

@testset "shock diagnostics and positional validation" begin
    forms = ("at(period", "during(first:last")
    for ex in (:(at(1, drift)), :(at(1, drift == 2)), :(at(1)),
               :(during(1, drift = 2)), :(during(2:1, drift = 2)),
               :(at(1, drift = x)), :(at(1, drift = NaN)),
               :(at(1, drift = -true)), :(at(1, drift = +false)))
        msg = error_message(() -> PKAssetPrices.ModelCore.parse_shock_entries(
            Expr(:block, ex)))
        @test !isempty(msg)
        @test all(occursin(form, msg) for form in forms)
        @test occursin("at", msg) || occursin("during", msg)
    end
    @test PKAssetPrices.ModelCore.parse_shock_entries(
        :(begin at(+1, drift = -2, x = +3); during(-1:1, drift = 4) end)) |> length == 3

    for bad in ((:a, 1, nothing, true, "entry"), (:a, Inf, nothing, 1, "entry"),
                (:a, 2, 1, 1, "entry"), (:a, 1, nothing, 1, 17))
        msg = error_message(() -> Shock(bad...))
        @test occursin("Shock(", msg) && occursin("Shock(;", msg)
        @test occursin("entry", msg) || occursin("17", msg)
    end
    @test_throws Exception Shock(:a, big(10.0)^400, nothing, 1, "overflow")
    @test Shock(:drift, 1, nothing, 2, :converted).source == "converted"
    @test fieldtypes(Shock) == (Symbol, Float64, Union{Float64,Nothing}, Float64, String)

    duplicate_block = :(begin
        @shocks begin at(1, drift = 1.0) end
        @shocks begin at(2, drift = 2.0) end
    end)
    duplicate_block_message = error_message(() ->
        PKAssetPrices.ModelCore.parse_dynamic_scenario_entries(duplicate_block))
    @test_throws Exception PKAssetPrices.ModelCore.parse_dynamic_scenario_entries(duplicate_block)
    @test occursin("Duplicate", duplicate_block_message)
    @test occursin("@shocks", duplicate_block_message)
    @test occursin("offending expression", duplicate_block_message)

    unknown_block = :(begin @curves begin drift = 1.0 end end)
    unknown_block_message = error_message(() ->
        PKAssetPrices.ModelCore.parse_dynamic_scenario_entries(unknown_block))
    @test_throws Exception PKAssetPrices.ModelCore.parse_dynamic_scenario_entries(unknown_block)
    @test occursin("@curves", unknown_block_message)
    @test all(occursin(block, unknown_block_message) for block in ("@equations", "@init", "@shocks"))

    unknown_param_expr = :(@scenario LagOneShockFixture begin
        @shocks begin at(2, typo = 1.0) end
    end)
    unknown_param_message = error_message(() -> Core.eval(@__MODULE__, unknown_param_expr))
    @test_throws Exception Core.eval(@__MODULE__, unknown_param_expr)
    @test occursin("typo", unknown_param_message)
    @test occursin("at(2, typo = 1.0)", unknown_param_message)
    @test occursin("declared parameters", unknown_param_message)
    @test occursin("drift", unknown_param_message)

    outside_after_expr = :(@scenario LagOneShockFixture begin
        @shocks begin at(10, drift = 1.0) end
    end)
    outside_after_message = error_message(() -> Core.eval(@__MODULE__, outside_after_expr))
    @test_throws Exception Core.eval(@__MODULE__, outside_after_expr)
    @test occursin("10.0", outside_after_message)
    @test occursin("grid 1.0:3.0", outside_after_message)
    @test occursin("at(10, drift = 1.0)", outside_after_message)

    outside_before_expr = :(@scenario LagOneShockFixture begin
        @shocks begin during(-10:-5, drift = 1.0) end
    end)
    outside_before_message = error_message(() -> Core.eval(@__MODULE__, outside_before_expr))
    @test_throws Exception Core.eval(@__MODULE__, outside_before_expr)
    @test occursin("-10.0", outside_before_message) && occursin("-5.0", outside_before_message)
    @test occursin("grid 1.0:3.0", outside_before_message)
    @test occursin("during(-10:-5, drift = 1.0)", outside_before_message)

    duplicate_expr = :(@scenario LagOneShockFixture begin
        @shocks begin
            at(2, drift = 1.0)
            at(2, drift = 1.0)
        end
    end)
    duplicate_message = error_message(() -> Core.eval(@__MODULE__, duplicate_expr))
    @test_throws Exception Core.eval(@__MODULE__, duplicate_expr)
    @test occursin("Duplicate identical", duplicate_message)
    @test occursin("at(2, drift = 1.0)", duplicate_message)

    unsorted_expr = :(@model begin
        @time [2.0, 1.0]
        @variables begin x end
        @parameters begin drift = 0.5 end
        @equations begin x[t] == drift end
    end)
    unsorted_message = error_message(() -> Core.eval(@__MODULE__, unsorted_expr))
    @test_throws Exception Core.eval(@__MODULE__, unsorted_expr)
    @test occursin("non-decreasing @time grid", unsorted_message)
    @test occursin("test_shocks.jl", unsorted_message)

    bad_model = D.DynamicModel(
        time=D.DiscreteTime([2.0, 1.0]),
        variables=LagOneShockFixture.model.variables,
        params=LagOneShockFixture.model.params,
        equations=LagOneShockFixture.model.equations,
        nulls=LagOneShockFixture.model.nulls,
        eval=LagOneShockFixture.model.eval,
        stocks=LagOneShockFixture.model.stocks,
        stocks_eval=LagOneShockFixture.model.stocks_eval,
        balance_sheets=LagOneShockFixture.model.balance_sheets,
        sheet_eval=LagOneShockFixture.model.sheet_eval,
    )
    rebuild_message = error_message(() -> D._rebuild_dynamic_model(
        bad_model, bad_model.equations, LagOneShockFixture.init, "rebuild-test"))
    @test_throws Exception D._rebuild_dynamic_model(
        bad_model, bad_model.equations, LagOneShockFixture.init, "rebuild-test")
    @test occursin("rebuild-test", rebuild_message)
    @test occursin("non-decreasing", rebuild_message)
end

@testset "shocks apply to current grid values" begin
    base = LagOneShockFixture
    shocked(shocks) = DynamicParametrization(
        base.model, copy(base.params), base.init, base.u0,
        validate_shocks(shocks, base))

    @test D.solve_model(shocked([Shock(param=:drift, from=2, value=1)])).paths[:x] ==
        [1.5, 2.5, 3.5]
    @test D.solve_model(shocked([Shock(param=:drift, from=2, until=2, value=1)])).paths[:x] ==
        [1.5, 2.5, 3.0]
    grid_shock = shocked([Shock(param=:drift, from=2.5, value=1)])
    @test D.solve_model(grid_shock).paths[:x] == [1.5, 2.0, 3.0]

    overlap = shocked([
        Shock(param=:drift, from=2, value=1),
        Shock(param=:drift, from=2, until=2, value=3),
        Shock(param=:drift, from=3, value=2),
    ])
    @test D.solve_model(overlap).paths[:x] == [1.5, 4.5, 6.5]
    @test D.build_context(overlap, 2, Dict(:x => [1.5, 0.0, 0.0]))[:drift] == 3.0
    @test D.build_context(overlap, 3, Dict(:x => [1.5, 3.5, 0.0]))[:drift] == 2.0

    context = D.build_context(grid_shock, 3, Dict(:x => [1.5, 2.0, 0.0]))
    @test context[:drift] === 1.0
    @test D.eval_model(grid_shock, Dict(:x => 2.0), Dict(:x => 1.5)) ≈ [2.0]

    # The documented override rule resumes the base drift after during(2:2),
    # so the final value is 3.0 rather than the conflicting [.., 2.5] oracle.
    @test D.solve_model(shocked([Shock(param=:drift, from=2, until=2, value=1)])).paths[:x] ==
        [1.5, 2.5, 3.0]
end

@testset "shock propagation keeps independent vectors" begin
    base = D.set_shocks(D.DynαQCr, [Shock(:c₀, 2, nothing, 1, "propagation")])
    updated = D.update_params(base, collect(values(base.params))[1:14])
    @test updated.shocks == base.shocks && updated.shocks !== base.shocks
end

@testset "shocks flow through stocks and sheets" begin
    stock = DynamicParametrization(
        StockShockFixture.model, copy(StockShockFixture.params),
        StockShockFixture.init, StockShockFixture.u0,
        validate_shocks([Shock(param=:increment, from=2, value=2)], StockShockFixture))
    stock_solution = D.solve_model(stock)
    @test stock_solution.paths[:x] == [1.5, 3.5, 5.5]
    @test stock_solution.paths[:y] == [1.5, 3.5, 5.5]

    sheet = DynamicParametrization(
        SheetShockFixture.model, copy(SheetShockFixture.params),
        SheetShockFixture.init, SheetShockFixture.u0,
        validate_shocks([Shock(param=:asset_value, from=2, value=4)], SheetShockFixture))
    solution = D.solve_model(sheet)
    @test [only(s).assets[1].second for s in solution.sheets] == [1.0, 4.0, 4.0]
    @test [only(s).liabilities[1].second for s in solution.sheets] == [1.0, 4.0, 4.0]
end

@testset "shocks do not affect shipped model baseline solves" begin
    for name in (:WorkingModel, :DynQ, :Dynα, :DynαQ, :DynαQCr)
        @test_nowarn D.solve_model(getproperty(D, name))
    end
end

@testset "set_shocks / shocks API" begin
    base = DynamicParametrization(
        LagOneShockFixture.model, copy(LagOneShockFixture.params),
        LagOneShockFixture.init, LagOneShockFixture.u0)
    @test isempty(D.shocks(base))

    new_shocks = [Shock(param=:drift, from=2, value=1.0)]
    dp2 = D.set_shocks(base, new_shocks)

    # set -> accessor roundtrip
    @test D.shocks(dp2) == new_shocks
    @test D.shocks(dp2) === dp2.shocks

    # model reference shared
    @test dp2.model === base.model

    # input dp unchanged
    @test D.shocks(base) == Shock[]
    @test base.params == Dict(:drift => 0.5)
    @test base.init == Dict(:x => [1.0])
    @test base.u0 == LagOneShockFixture.u0
    @test D.solve_model(base).paths[:x] == [1.5, 2.0, 2.5]

    # deep-copied mutable fields are independent
    @test dp2.params !== base.params
    @test dp2.init !== base.init
    @test dp2.u0 !== base.u0
    @test dp2.shocks !== base.shocks

    # set -> solve gives the hand-computed LagOne expected path
    #   t1: x = 1.0 + 0.5 = 1.5
    #   t2: drift=1, x = 1.5 + 1.0 = 2.5
    #   t3: drift=1 (open window), x = 2.5 + 1.0 = 3.5
    @test D.solve_model(dp2).paths[:x] == [1.5, 2.5, 3.5]

    # replacing existing shocks rather than appending
    dp3 = D.set_shocks(dp2, [Shock(param=:drift, from=3, value=2.0)])
    @test length(D.shocks(dp3)) == 1
    @test D.shocks(dp3)[1].param === :drift
    @test D.shocks(dp3)[1].from === 3.0
    #   t1: 1.5, t2: 2.0 (drift 0.5), t3: 4.0 (drift 2.0)
    @test D.solve_model(dp3).paths[:x] == [1.5, 2.0, 4.0]
    @test length(D.shocks(dp2)) == 1   # dp2 unaffected by replacing dp3

    # validation errors propagate
    @test_throws Exception D.set_shocks(base, [Shock(param=:z, from=1, value=1)])   # unknown parameter
    @test_throws Exception D.set_shocks(base, [Shock(param=:drift, from=10, value=1)])  # outside grid
    @test_throws Exception D.set_shocks(base,
        [Shock(param=:drift, from=2, value=1), Shock(param=:drift, from=2, value=1)])  # duplicate
end
end
