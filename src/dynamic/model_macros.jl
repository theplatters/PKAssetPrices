import ..BaseModels: Equation

"Parse a @flows or @stocks block: x = \"desc\" or just x"
function _parse_dynvars!(out::Vector{DynVar}, body)
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Symbol
            push!(out, DynVar(line, ""))
        elseif line isa Expr && line.head == :(=)
            name = line.args[1]
            desc = line.args[2]
            name isa Symbol || error("Expected Symbol on LHS in @flows/@stocks, got $name")
            push!(out, DynVar(name, String(desc)))
        else
            error("Invalid entry in @flows/@stocks: $line")
        end
    end
    return
end

"Parse @parameters: a = 0.5, \"desc\"  OR  a = 0.5"
function _parse_params!(params::Vector{DynVar}, defaults::Dict{Symbol, Any}, body)
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(=)
            k = line.args[1]
            rhs = line.args[2]
            k isa Symbol || error("Parameter name must be a Symbol, got $k")

            if rhs isa Expr && rhs.head == :tuple
                defaults[k] = rhs.args[1]     # can be scalar or vector expression
                desc = rhs.args[2]
                push!(params, DynVar(k, String(desc)))
            else
                defaults[k] = rhs
                push!(params, DynVar(k, ""))
            end
        else
            error("Invalid parameter specification: $line")
        end
    end
    return
end

"Parse @equations: lhs == rhs"
function _parse_equations!(eqs::Vector{Equation}, body)
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :call && line.args[1] == :(==)
            push!(eqs, Equation(line.args[2], line.args[3]))
        else
            error("@equations entries must be `lhs == rhs`, got: $line")
        end
    end
    return
end

function _parse_init!(init, body)
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(=)
            name = line.args[1]
            value = line.args[2]
            @info value
            init[name] = value
        else
            error("@equations entries must be `lhs == rhs`, got: $line")
        end
    end
    return
end

# -------- time index validation & rewriting --------

"Return true if expr contains `sym[t]` or `sym[t-1]`-style indexing"
function _contains_time_index(expr, syms::Set{Symbol})
    expr isa Expr || return false
    if expr.head == :ref && expr.args[1] isa Symbol && (expr.args[1] in syms)
        return true
    end
    return any(_contains_time_index(a, syms) for a in expr.args)
end

"Check that only stocks are indexed, and only with [t] or [t-1]."
function _validate_time_indexing!(eqs::Vector{Equation}, stocks::Vector{DynVar}, flows::Vector{DynVar})
    stockset = Set(v.name for v in stocks)
    flowset = Set(v.name for v in flows)

    function check_expr(ex)
        ex isa Expr || return
        if ex.head == :ref
            base = ex.args[1]
            base isa Symbol || error("Invalid time indexing: $ex")
            if base in flowset
                error("Flows cannot be time-indexed: found $ex")
            elseif !(base in stockset)
                error("Only stocks may be time-indexed: found $ex")
            end
            # Only allow [t] and [t-1]
            idx = ex.args[2]
            ok = (idx == :t) ||
                (idx isa Expr && idx.head == :call && idx.args[1] == :- && idx.args[2] == :t && idx.args[3] == 1) ||
                (idx isa Expr && idx.head == :call && idx.args[1] == :- && idx.args[2] == :t && idx.args[3] == :(1))
            ok || error("Only [t] and [t-1] are allowed for stocks. Found: $ex")
        end
        for a in ex.args
            check_expr(a)
        end
        return
    end

    for eq in eqs
        check_expr(eq.lhs)
        check_expr(eq.rhs)
    end
    return
end

"""
Rewrite stock refs:
- x[t]    -> x       (current stocks are unknowns in u)
- x[t-1]  -> (Symbol(\"x[t - 1]\"))  (lookup from p as key :(x[t - 1]))
"""
function _rewrite_time_refs(expr, stockset::Set{Symbol})
    expr isa Expr || return expr

    if expr.head == :ref && expr.args[1] isa Symbol && (expr.args[1] in stockset)
        x = expr.args[1]
        idx = expr.args[2]
        if idx == :t
            return x
        else
            # treat anything not :t (we validated) as t-1
            return Symbol(x, "[t - 1]")
        end
    end

    return Expr(expr.head, (_rewrite_time_refs(a, stockset) for a in expr.args)...)
end

# -------- nulls generation for DynamicModel --------

function _generate_nulls(flows::Vector{DynVar}, stocks::Vector{DynVar}, params::Vector{DynVar}, eqs::Vector{Equation})
    flow_syms = [v.name for v in flows]
    stock_syms = [v.name for v in stocks]
    param_syms = [v.name for v in params]

    stockset = Set(stock_syms)

    # variables in u are flows then current stocks
    var_tuple = Expr(:tuple, vcat(flow_syms, stock_syms)...)

    # rewrite equations to:
    # - current stocks as symbols in u
    # - lagged stocks as Symbol("x[t - 1]") that will be destructured from p
    rewritten = Equation[]
    for eq in eqs
        push!(
            rewritten, Equation(
                _rewrite_time_refs(eq.lhs, stockset),
                _rewrite_time_refs(eq.rhs, stockset),
            )
        )
    end

    # collect lag symbols we need to destructure from p
    lag_syms = Symbol[]
    for s in stock_syms
        push!(lag_syms, Symbol(string(s), "[t - 1]"))
    end

    residuals = [:($(eq.lhs) - $(eq.rhs)) for eq in rewritten]

    return quote
        function (u, p)
            (; $(param_syms...), $(lag_syms...)) = p
            $var_tuple = u
            return [$(residuals...)]
        end
    end
end

# -------- public macros --------

"""
Dynamic model DSL:

@model begin
@time 0.0:1.0:100.0

@flows begin
  Y = "output"
  C = "consumption"
end

@stocks begin
  K = "capital"
  B = "debt"
end

@parameters begin
  α = 0.3, "share"
  β = ones(101), "time varying"  # allowed; used by your solver build_context
end

@equations begin
  Y == C + I
  K[t] == K[t-1] + I - δ*K[t-1]
end
end
"""
macro model(body)
    time_expr = nothing
    flows = DynVar[]
    stocks = DynVar[]
    params = DynVar[]
    defaults = Dict{Symbol, Any}()
    eqs = Equation[]
    init = Dict{Symbol, Float64}()

    for expr in body.args
        expr isa LineNumberNode && continue
        if !(expr isa Expr && expr.head == :macrocall)
            continue
        end
        mac = expr.args[1]
        blk = expr.args[3]

        if mac == Symbol("@time")
            # @time 0.0:1.0:100.0
            time_expr = blk
        elseif mac == Symbol("@flows")
            _parse_dynvars!(flows, blk)
        elseif mac == Symbol("@stocks")
            _parse_dynvars!(stocks, blk)
        elseif mac == Symbol("@parameters")
            _parse_params!(params, defaults, blk)
        elseif mac == Symbol("@equations")
            _parse_equations!(eqs, blk)
        elseif mac == Symbol("@init")
            _parse_init!(init, blk)
        end
    end

    time_expr === nothing && error("Dynamic @model requires a @time block, e.g. @time 0.0:1.0:100.0")

    _validate_time_indexing!(eqs, stocks, flows)

    nulls = _generate_nulls(flows, stocks, params, eqs)

    # default u0: ones(nFlows+nStocks)
    n = length(flows) + length(stocks)

    return esc(
        quote
            let
                local grid = collect($time_expr)
                local m = DynamicModel(
                    DiscreteTime(grid),
                    $stocks,
                    $flows,
                    $params,
                    $eqs,
                    $nulls
                )

                # Create a default parametrization:
                # - params defaults (can be scalars or vectors)
                # - init empty (user should fill)
                # - u0 ones
                DynamicParametrization(
                    m,
                    Dict{Symbol, Union{Float64, Vector{Float64}}}($((:($(QuoteNode(k)) => $(v)) for (k, v) in defaults)...)),
                    $init,
                    ones($n),
                )
            end
        end
    )
end
