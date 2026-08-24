module ValidationTests

using Test
using PKAssetPrices

function expand_static(ex)
    macroexpand(PKAssetPrices.Static, ex)
end

function expand_dynamic(ex)
    macroexpand(PKAssetPrices.Dynamic, ex)
end

@testset "strict model block validation" begin
    @test_throws r"Unknown static.*@variables.*@parameters" expand_static(
        :(@model begin
            @unknown begin end
        end))
    @test_throws r"Unknown dynamic.*@time.*@variables" expand_dynamic(
        :(@model begin
            @unknown begin end
        end))

    @test_throws r"Invalid static @model entry" expand_static(
        :(@model begin
            123
        end))
    @test_throws r"Invalid dynamic @model entry" expand_dynamic(
        :(@model begin
            123
        end))

    @test_throws r"Invalid variable entry|Variable name" expand_static(
        :(@model begin
            @variables begin
                x + 1
            end
        end))
    @test_throws r"Invalid variable entry|Variable name" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x + 1
            end
        end))

    @test_throws r"Invalid parameter entry|Parameter name" expand_static(
        :(@model begin
            @parameters begin
                x + 1
            end
        end))
    @test_throws r"Invalid parameter entry|Parameter name" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @parameters begin
                x + 1
            end
        end))

    @test_throws r"@equations entries" expand_static(
        :(@model begin
            @equations begin
                x = 1
            end
        end))
    @test_throws r"@equations entries" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @equations begin
                x = 1
            end
        end))

    @test_throws r"@init entries" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @init begin
                x + 1
            end
        end))

    @test_throws r"Invalid curve entry" expand_static(
        :(@model begin
            @curves begin
                not_a_curve = 1
            end
        end))
    @test_throws r"Invalid @balances entry|Malformed @sheet" expand_static(
        :(@model begin
            @balances begin
                garbage
            end
        end))

    @test_throws r"@scenario entries" expand_static(
        :(@scenario StaticInitFixture begin
            garbage
        end))
    @test_throws r"@scenario entries" expand_dynamic(
        :(@scenario DynamicSolveFixture begin
            garbage
        end))
end

@testset "definition-time structural validation" begin
    @test_throws r"static @model at .*duplicate variable declaration.*x" expand_static(
        :(@model begin
            @variables begin
                x = "x"
                x = "duplicate x"
            end
            @equations begin
                x == 1
            end
        end))
    @test_throws r"dynamic @model at .*duplicate variable declaration.*x" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x = "x"
                x = "duplicate x"
            end
            @equations begin
                x[t] == 1
            end
        end))

    @test_throws r"static @model at .*duplicate parameter declaration.*p" expand_static(
        :(@model begin
            @parameters begin
                p = 1.0
                p = 2.0
            end
        end))
    @test_throws r"dynamic @model at .*duplicate parameter declaration.*p" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @parameters begin
                p = 1.0
                p = 2.0
            end
        end))

    @test_throws r"static @model at .*collision.*x" expand_static(
        :(@model begin
            @variables begin
                x = "variable"
            end
            @parameters begin
                x = 1.0
            end
            @equations begin
                x == 1
            end
        end))
    @test_throws r"dynamic @model at .*collision.*x" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x = "variable"
            end
            @parameters begin
                x = 1.0
            end
            @equations begin
                x[t] == 1
            end
        end))

    structural_static = :(@model begin
        @variables begin
            x = "x"
            y = "y"
        end
        @parameters begin
            p = 1.0
        end
        @equations begin
            x == p
            x == p
        end
    end)
    @test_throws r"static @model at .*missing equation LHS.*y.*duplicate equation LHS.*x" expand_static(structural_static)

    structural_dynamic = :(@model begin
        @time 0.0:1.0:1.0
        @variables begin
            x = "x"
            y = "y"
        end
        @parameters begin
            p = 1.0
        end
        @equations begin
            x[t] == p
            x[t] == p
        end
    end)
    @test_throws r"dynamic @model at .*missing equation LHS.*y.*duplicate equation LHS.*x" expand_dynamic(structural_dynamic)

    @test_throws r"static @model at .*undeclared equation LHS.*z" expand_static(
        :(@model begin
            @variables begin
                x = "x"
            end
            @equations begin
                z == 1
            end
        end))
    @test_throws r"dynamic @model at .*undeclared equation LHS.*z" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x = "x"
            end
            @equations begin
                z[t] == 1
            end
        end))

    @test_throws r"static @model at .*unknown symbol.*typo" expand_static(
        :(@model begin
            @variables begin
                x = "x"
            end
            @equations begin
                x == typo + 1
            end
        end))
    @test_throws r"dynamic @model at .*unknown symbol.*typo" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x = "x"
            end
            @equations begin
                x[t] == typo + 1
            end
        end))

    @test_throws r"dynamic @model at .*unknown symbol.*t" expand_dynamic(
        :(@model begin
            @time 0.0:1.0:1.0
            @variables begin
                x = "x"
            end
            @equations begin
                x[t] == t
            end
        end))

    @test_throws r"exactly one index" PKAssetPrices.Dynamic.check_expr(:(x[t, 2]))
    @test_throws r"Invalid time reference x\[t \+ 1\].*future" PKAssetPrices.Dynamic.check_expr(:(x[t + 1]))
    @test_nowarn PKAssetPrices.Dynamic.check_expr(:(x[t - 3]))

    @test_throws r"indexed reference.*static equation" expand_static(
        :(@model begin
            @variables begin
                x = "x"
                y = "y"
            end
            @equations begin
                x == y[t]
                y == 1
            end
        end))

    @test_nowarn expand_static(:(@model begin
        @variables begin
            x = "x"
        end
        @parameters begin
            p = 1.0
        end
        @equations begin
            x == sqrt(p) + exp(p) + log(p) + abs(p) + min(p, p) + max(p, p) + π
        end
    end))

    @test_logs (:warn, r"y requires history length 1") (:warn, r"x requires history length 2") expand_dynamic(:(@model begin
        @time 0.0:1.0:2.0
        @variables begin
            x = "x"
            y = "y"
        end
        @parameters begin
            p = 1.0
        end
        @equations begin
            x[t] == p + y[t - 1]
            y[t] == x[t - 2]
        end
    end))

    @test_nowarn expand_static(:(@model begin
        @variables begin
            x = "x"
        end
        @parameters begin
            a = 1.0
        end
        @equations begin
            x == let k = a; k end
        end
    end))
    @test_nowarn expand_static(:(@model begin
        @variables begin
            x = "x"
        end
        @parameters begin
            a = 1.0
            b = 2.0
        end
        @equations begin
            x == let k = a, j = b; k + j end
        end
    end))
    @test_nowarn expand_static(:(@model begin
        @variables begin
            x = "x"
        end
        @parameters begin
            a = 1.0
        end
        @equations begin
            x == let; k = a + 1; k end
        end
    end))

    @test_nowarn expand_static(:(@model begin
        @variables begin
            x = "x"
        end
        @parameters begin
            a = 1.0
        end
        @equations begin
            x == let k = a; j = k + 1; j end
        end
    end))
end

end
