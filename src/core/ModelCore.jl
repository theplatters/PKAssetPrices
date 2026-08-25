module ModelCore

export AbstractModel, Equation, Lag, lag_key, BalanceSheet, BalanceSheetFilled,
       parse_balance!, parse_balances!, check_accounting, parse_shock_entries

"""Describe a positive historical lag.

```jldoctest
julia> Lag(:capital, 2).k
2
```
"""
struct Lag
    var::Symbol
    k::Int
    function Lag(var::Symbol, k::Int)
        k >= 1 || error("Lag depth must be at least 1; use a positive integer for k (got $k).")
        new(var, k)
    end
end

"""Return the canonical context key for variable `var` at lag `k`.

```jldoctest
julia> lag_key(:capital, 2)
:"capital[t - 2]"
```
"""
function lag_key(var::Symbol, k::Int)::Symbol
    k >= 1 || error("Lag depth must be at least 1; use a positive integer for k (got $k).")
    return Symbol(var, "[t - ", k, "]")
end

include("ast.jl")
include("parse.jl")
include("codegen.jl")
include("validate.jl")
include("balances.jl")

"""Common accounting checker; model-face methods provide the sheet collection.

For a dynamic solution, `check_accounting(sol)` returns a named tuple with
`consistent` and the vector `periods`; `check_accounting(sol, t)` returns the
single period result. Static solutions return the single period result.

```jldoctest
julia> result = PKAssetPrices.check_accounting(
           PKAssetPrices.solve_model(PKAssetPrices.Static.Baseline));

julia> result.consistent
true
```
"""
function check_accounting end

end
