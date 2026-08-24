import ..ModelCore: Equation

"Parse a @flows or @stocks block: x = \"desc\" or just x"
function _parse_dynvars!(out::Vector{DynVar}, body)
    for (name, desc) in ModelCore.parse_variable_entries(body; stringify_description=true)
        push!(out, DynVar(name, desc))
    end
    return
end

"Parse @parameters: a = 0.5, \"desc\"  OR  a = 0.5"
function _parse_params!(params::Vector{DynVar}, defaults::Dict{Symbol, Any}, body)
    for (k, value_desc) in ModelCore.parse_parameter_entries(body; stringify_description=true)
        value, desc = value_desc
        defaults[k] = value
        push!(params, DynVar(k, desc))
    end
    return
end

"Parse @equations: lhs == rhs"
function _parse_equations!(eqs::Vector{Equation}, body)
    for (lhs, rhs) in ModelCore.parse_equation_entries(body)
        push!(eqs, Equation(lhs, rhs))
    end
    return
end

function _parse_init!(init, body)
    body isa Expr && body.head == :block || error("Expected a begin...end block for @init, got: $body")
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(=) && length(line.args) == 2 && line.args[1] isa Symbol
            name = line.args[1]
            value = line.args[2]
            init[name] = vcat(eval(value))
        else
            error("@init entries must be `name = value`, got: $line")
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

function _time_lag(idx)
    idx == :t && return 0
    if idx isa Expr && idx.head == :call && length(idx.args) == 3 &&
            idx.args[1] == :- && idx.args[2] == :t && idx.args[3] in (1, 2)
        return idx.args[3]
    end
    return nothing
end

function check_expr(ex)
    ex isa Expr || return
    if ex.head == :ref
        length(ex.args) == 2 ||
            error("Time references must have exactly one index: $ex")
        base = ex.args[1]
        base isa Symbol || error("Invalid time indexing: $ex")

        idx = ex.args[2]
        isnothing(_time_lag(idx)) && error("Only [t], [t-1], and [t-2] are allowed for variables. Found: $ex")
    end
    for a in ex.args
        check_expr(a)
    end
    return
end

"Check that variables are indexed only with [t], [t-1], or [t-2]."
function _validate_time_indexing!(eqs::Vector{Equation})
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
- x[t-2]  -> (Symbol(\"x[t - 2]\"))  (lookup from p as key :(x[t - 2]))
"""
function _rewrite_time_refs(expr, stockset::Set{Symbol})
    # If it's a stock variable without indexing, treat it as [t]
    if expr isa Symbol && expr in stockset
        return expr
    end

    expr isa Expr || return expr

    if expr.head == :ref && expr.args[1] isa Symbol && (expr.args[1] in stockset)
        x = expr.args[1]
        idx = expr.args[2]
        lag = _time_lag(idx)
        if lag == 0
            return x
        end
        isnothing(lag) && error("Invalid time index in $expr")
        return Symbol(x, "[t - $lag]")
    end

    return Expr(expr.head, (_rewrite_time_refs(a, stockset) for a in expr.args)...)
end

function _rewrite_equations(eqs::Vector{Equation}, variable_set::Set{Symbol})
    return [Equation(
        _rewrite_time_refs(eq.lhs, variable_set),
        _rewrite_time_refs(eq.rhs, variable_set),
    ) for eq in eqs]
end

function _collect_symbols!(symbols::Set{Symbol}, expr)
    if expr isa Symbol
        push!(symbols, expr)
    elseif expr isa Expr
        for arg in expr.args
            _collect_symbols!(symbols, arg)
        end
    end
    return symbols
end

function _required_lag_symbols(equations::Vector{Equation}, variable_syms::Vector{Symbol})
    used = Set{Symbol}()
    for eq in equations
        _collect_symbols!(used, eq.lhs)
        _collect_symbols!(used, eq.rhs)
    end

    candidates = Symbol[]
    for variable in variable_syms, lag in 1:2
        push!(candidates, Symbol(variable, "[t - $lag]"))
    end
    return filter(in(used), candidates)
end

# -------- nulls generation for DynamicModel --------


function _generate_nulls(variables::Vector{DynVar}, params::Vector{DynVar}, eqs::Vector{Equation})
    variable_syms = [v.name for v in variables]
    param_syms = [v.name for v in params]

    variable_set = Set(variable_syms)

    # variables in u are flows then current stocks
    var_tuple = Expr(:tuple, variable_syms...)

    # rewrite equations to:
    # - current stocks as symbols in u
    # - lagged values as synthetic symbols that will be destructured from p
    rewritten = _rewrite_equations(eqs, variable_set)

    # Destructure only the lagged values referenced by this model.
    lag_syms = _required_lag_symbols(rewritten, variable_syms)

    return ModelCore.generate_residual_closure(
        variables, param_syms, rewritten; lag_symbols=lag_syms)
end


function _generate_eval(variables::Vector{DynVar}, params::Vector{DynVar}, eqs::Vector{Equation})
    variable_syms = [v.name for v in variables]
    param_syms = [v.name for v in params]

    variable_set = Set(variable_syms)

    # rewrite equations:
    # - x[t]   -> x
    # - x[t-1] -> Symbol("x[t - 1]")
    # - x[t-2] -> Symbol("x[t - 2]")
    rewritten = _rewrite_equations(eqs, variable_set)

    # Lagged variable symbols expected in p.
    lag_syms = _required_lag_symbols(rewritten, variable_syms)

    # for evaluation, return rhs expressions
    values = [eq.rhs for eq in rewritten]

    # destructure everything from p as named fields
    all_syms = vcat(param_syms, lag_syms, variable_syms)

    return quote
        function (p)
            (; $(all_syms...)) = p
            return [$(values...)]
        end
    end
end


# -------- public macros --------

"""
    Name = @model begin ... end

Define a dynamic model and return a [`DynamicParametrization`](@ref). The
body requires `@time` and supports `@variables`, `@parameters`, `@init`, and
`@equations`. Variables may be indexed at `t`, `t-1`, or `t-2` in the
equations.

```julia
Example = @model begin
    @time 0.0:1.0:10.0
    @variables begin
        Y = "output"
        K = "capital"
    end
    @parameters begin
        a = 0.5, "capital share"
    end
    @init begin
        K = [1.0]
    end
    @equations begin
        Y[t] == a * K[t - 1]
        K[t] == K[t - 1] + Y[t]
    end
end
```
"""
macro model(body)
    time_expr = nothing
    params = DynVar[]
    variables = DynVar[]
    defaults = Dict{Symbol, Any}()
    eqs = Equation[]
    init = Dict{Symbol, Vector{Float64}}()

    for expr in body.args
        expr isa LineNumberNode && continue
        expr isa Expr && expr.head == :macrocall ||
            error("Invalid dynamic @model entry (expected a macro block): $expr")
        length(expr.args) == 3 || error("Malformed dynamic macro block: $expr")
        mac = expr.args[1]
        blk = expr.args[3]

        if mac == Symbol("@time")
            # @time 0.0:1.0:100.0
            time_expr = blk
        elseif mac == Symbol("@variables")
            _parse_dynvars!(variables, blk)
        elseif mac == Symbol("@parameters")
            _parse_params!(params, defaults, blk)
        elseif mac == Symbol("@equations")
            _parse_equations!(eqs, blk)
        elseif mac == Symbol("@init")
            _parse_init!(init, blk)
        else
            error("Unknown dynamic @model block $mac. Valid blocks: @time, @variables, @parameters, @init, @equations")
        end
    end

    time_expr === nothing && error("Dynamic @model requires a @time block, e.g. @time 0.0:1.0:100.0")

    _validate_time_indexing!(eqs)

    source = "$(__source__.file):$(__source__.line)"
    rewritten_for_validation = _rewrite_equations(eqs, Set(v.name for v in variables))
    ModelCore.validate_model(
        :dynamic, source, [v.name for v in variables], [p.name for p in params],
        rewritten_for_validation)

    eval_fun = _generate_eval(variables, params, eqs)

    nulls = _generate_nulls(variables, params, eqs)

    # default u0: ones(nFlows+nStocks)
    n = length(variables)

    return esc(
        quote
            DynamicParametrization(
                DynamicModel(
                    DiscreteTime(collect($time_expr)),
                    $variables,
                    $params,
                    $eqs,
                    $nulls,
                    $eval_fun
                ),
                Dict{Symbol, Float64}($((:($(QuoteNode(k)) => $(v)) for (k, v) in defaults)...)),
                $init,
                ones($n),
            )
        end
    )
end


macro scenario(model, body)
    assigns = Expr[]
    for (name, value) in ModelCore.parse_scenario_entries(body)
        unknown_message = "@scenario parameter $(name) is not declared in the base model"
        push!(assigns, quote
            haskey(params, $(QuoteNode(name))) ||
                error($unknown_message)
            params[$(QuoteNode(name))] = $value
        end)
    end

    return esc(
        quote
            local m = $model
            local params = copy(m.params)
            $(assigns...)
            Dynamic.DynamicParametrization(m.model, params, deepcopy(m.init), copy(m.u0))  # note: no "&" in Julia
        end
    )
end
