import ..ModelCore: Equation, Lag, lag_key

"Parse a @variables block: x = \"desc\" or just x."
function _parse_dynvars!(out::Vector{DynVar}, body)
    for (name, desc) in ModelCore.parse_variable_entries(body; stringify_description=true)
        push!(out, DynVar(name, desc))
    end
    return
end

function _parse_stocks!(out::Vector{Symbol}, declarations::Dict{Symbol, String}, body, source)
    entries = ModelCore.parse_variable_entries(body; stringify_description=true)
    lines = [line for line in body.args if !(line isa LineNumberNode)]
    for ((name, _), line) in zip(entries, lines)
        name in out && error("Dynamic @model at $source: duplicate @stocks declaration for " *
            "$name in `$line`. Declare each stock once; remove the duplicate declaration.")
        push!(out, name)
        declarations[name] = string(line)
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

"Return true if expr contains a time-indexed variable reference."
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
            idx.args[1] == :- && idx.args[2] == :t &&
            idx.args[3] isa Integer && idx.args[3] >= 1
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
        isnothing(_time_lag(idx)) && error(
            "Invalid time reference $ex: Only [t] or a literal past index [t-k] is allowed. " *
            "Use t for the current period or t - k with an integer k >= 1; future and " *
            "non-integer indices are not supported.")
    end
    for a in ex.args
        check_expr(a)
    end
    return
end

"Check that variable references use the current period or a literal past period."
function _validate_time_indexing!(eqs::Vector{Equation})
    for eq in eqs
        check_expr(eq.lhs)
        check_expr(eq.rhs)
    end
    return
end

"""Rewrite current references to variables and past references to context keys."""
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
        return lag_key(x, lag)
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

function _discover_lags(equations::Vector{Equation}, variable_syms::Vector{Symbol})
    result = Lag[]
    function visit(ex)
        ex isa Expr || return
        if ex.head == :ref && length(ex.args) == 2 && ex.args[1] isa Symbol
            lag = _time_lag(ex.args[2])
            lag !== nothing && lag > 0 && ex.args[1] in variable_syms &&
                push!(result, Lag(ex.args[1], lag))
        end
        for arg in ex.args
            visit(arg)
        end
    end
    for eq in equations
        visit(eq.lhs); visit(eq.rhs)
    end
    return unique(result)
end

function _required_lag_symbols(lags::Vector{Lag})
    return unique(lag_key(lag.var, lag.k) for lag in lags)
end

function _required_lag_depths(lags::Vector{Lag})
    depths = Dict{Symbol, Int}()
    for lag in lags
        depths[lag.var] = max(get(depths, lag.var, 0), lag.k)
    end
    return depths
end

# -------- nulls generation for DynamicModel --------


function _generate_nulls(variables::Vector{DynVar}, params::Vector{DynVar}, eqs::Vector{Equation},
                         stocks::Vector{Symbol})
    variable_syms = [v.name for v in variables]
    # Predetermined stocks are context inputs to the flow residual.
    param_syms = vcat([v.name for v in params], stocks)

    variable_set = Set(variable_syms)

    stockset = Set(stocks)
    flow_variables = [v for v in variables if !(v.name in stockset)]
    flow_eqs = [eq for eq in eqs if begin
        lhs = eq.lhs
        name = lhs isa Symbol ? lhs : (lhs isa Expr && lhs.head == :ref ? lhs.args[1] : nothing)
        !(name in stockset)
    end]

    # Rewrite current flow values as unknowns and lagged values as context keys.
    # Predetermined current stocks are supplied through the context.
    rewritten = _rewrite_equations(flow_eqs, variable_set)

    # Destructure only the lagged values referenced by this model.
    lag_syms = _required_lag_symbols(_discover_lags(eqs, variable_syms))

    return ModelCore.generate_residual_closure(
        flow_variables, param_syms, rewritten; lag_symbols=lag_syms)
end


function _generate_eval(variables::Vector{DynVar}, params::Vector{DynVar}, eqs::Vector{Equation})
    variable_syms = [v.name for v in variables]
    param_syms = [v.name for v in params]

    variable_set = Set(variable_syms)

    # Rewrite current references to x and past references to context keys.
    rewritten = _rewrite_equations(eqs, variable_set)

    # Lagged variable symbols expected in p.
    lag_syms = _required_lag_symbols(_discover_lags(eqs, variable_syms))

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

function _generate_stocks_eval(variables, params, eqs, stocks)
    variable_set = Set(v.name for v in variables)
    rewritten = _rewrite_equations(eqs, variable_set)
    by_name = Dict{Symbol, Any}()
    for eq in rewritten
        name = eq.lhs isa Symbol ? eq.lhs : eq.lhs.args[1]
        by_name[name] = eq.rhs
    end
    values = [by_name[name] for name in stocks]
    param_syms = [p.name for p in params]
    lag_syms = _required_lag_symbols(_discover_lags(eqs, [v.name for v in variables]))
    all_syms = vcat(param_syms, lag_syms)
    return quote
        function (p)
            (; $(all_syms...)) = p
            return [$(values...)]
        end
    end
end

function _scenario_lhs(eq)
    lhs = eq.lhs
    lhs isa Symbol && return lhs
    lhs isa Expr && lhs.head == :ref && !isempty(lhs.args) && lhs.args[1] isa Symbol && return lhs.args[1]
    return nothing
end

function _normalize_init(value)
    value isa Number && return [Float64(value)]
    value isa AbstractVector && return Float64[Float64(x) for x in value]
    error("Dynamic @scenario @init values must be scalars or vectors, got `$value`.")
end

"Rebuild all derived dynamic machinery from an immutable scenario copy."
function _rebuild_dynamic_model(base::DynamicModel, equations, init, source)
    variables = deepcopy(base.variables); params = deepcopy(base.params)
    stocks = deepcopy(base.stocks); sheets = deepcopy(base.balance_sheets)
    variable_names = [v.name for v in variables]
    _validate_time_indexing!(equations)
    for bs in sheets, rhs in values(bs.calculations)
        check_expr(rhs)
    end
    raw_sheet_eqs = [Equation(:_sheet, rhs) for bs in sheets for rhs in values(bs.calculations)]
    discovered_lags = _discover_lags(vcat(equations, raw_sheet_eqs), variable_names)
    for (name, depth) in _required_lag_depths(discovered_lags)
        length(get(init, name, Float64[])) >= depth || @warn("Dynamic scenario at $source: $name requires history length $depth, but @init provides $(length(get(init, name, Float64[]))). Add history values; missing older values are zero-padded.")
    end
    rewritten = _rewrite_equations(equations, Set(variable_names))
    ModelCore.validate_model(:dynamic, source, variable_names, [p.name for p in params], rewritten;
        discovered_lags=discovered_lags, label="dynamic @scenario")
    rewritten_sheets = [BalanceSheet(bs.name, bs.fields, bs.assets, bs.liabilities,
        Dict(k => _rewrite_time_refs(v, Set(variable_names)) for (k, v) in bs.calculations)) for bs in sheets]
    ModelCore._sheet_order(rewritten_sheets, vcat(variable_names, [p.name for p in params], _required_lag_symbols(discovered_lags)), source)
    for stock in stocks
        eq = only(e for e in rewritten if _scenario_lhs(e) == stock)
        found = Set{Symbol}(); _collect_symbols!(found, eq.rhs)
        offending = sort!(collect(intersect(found, Set(variable_names))))
        isempty(offending) || error("Dynamic @scenario at $source: stock equation $eq: $stock is marked @stocks but its equation uses current-period values ($(join(string.(offending), ", "))). Stocks must be predetermined by history alone; remove it from @stocks or reformulate (variables that depend on current flows stay in the simultaneous block).")
    end
    # Evaluate generated functions in Dynamic, not in the caller's module.
    eval_fun = Core.eval(@__MODULE__, _generate_eval(variables, params, equations))
    nulls = Core.eval(@__MODULE__, _generate_nulls(variables, params, equations, stocks))
    stocks_eval = Core.eval(@__MODULE__, _generate_stocks_eval(variables, params, equations, stocks))
    sheet_eval = Core.eval(@__MODULE__, ModelCore.generate_sheet_eval(rewritten_sheets, variable_names,
        [p.name for p in params]; lag_symbols=_required_lag_symbols(discovered_lags), source=source))
    return DynamicModel(time=DiscreteTime(copy(base.time.grid)), variables=variables, params=params,
        equations=deepcopy(equations), nulls=nulls, eval=eval_fun, stocks=stocks,
        stocks_eval=stocks_eval, balance_sheets=sheets, sheet_eval=sheet_eval)
end

function _dynamic_scenario(base::DynamicParametrization, param_overrides, equation_overrides,
                           init_overrides, source)
    params = deepcopy(base.params)
    for (name, value, expression) in param_overrides
        haskey(params, name) || error("Dynamic @scenario parameter $name is not declared in the base model (source/offending expression: $expression); fix or remove it.")
        value isa Real && !(value isa Bool) || error("Dynamic @scenario parameter $name must be a real value (source/offending expression: $expression); fix or remove the non-real override.")
        params[name] = value
    end
    equations = deepcopy(base.model.equations)
    valid = [_scenario_lhs(eq) for eq in equations]
    seen = Set{Symbol}()
    for (eq, expression) in equation_overrides
        lhs = _scenario_lhs(eq)
        lhs isa Symbol || error("Dynamic @scenario equation override has invalid LHS `$lhs` in offending equation `$expression`; fix or remove it.")
        lhs in seen && error("Duplicate dynamic @scenario equation override LHS $lhs in offending equation `$expression`; set it once.")
        push!(seen, lhs)
        lhs in valid || error("Unknown dynamic @scenario equation override LHS $lhs in offending equation `$expression` at $source. Valid LHS names: $(join(string.(filter(!isnothing, valid)), ", ")). Fix or remove the override.")
        equations[findfirst(==(lhs), valid)] = eq
    end
    init = deepcopy(base.init)
    declared = Set(v.name for v in base.model.variables)
    for (name, value, expression) in init_overrides
        name in declared || error("Unknown dynamic @scenario @init name $name in source/offending expression `$expression` at $source; declared variables are $(join(string.(sort!(collect(declared))), ", ")). Fix or remove it.")
        init[name] = _normalize_init(value)
    end
    model = _rebuild_dynamic_model(base.model, equations, init, source)
    return DynamicParametrization(model, params, init, deepcopy(base.u0))
end


# -------- public macros --------

"""
    Name = @model begin ... end

Define a dynamic model and return a [`DynamicParametrization`](@ref). The body
supports `@time`, `@variables`, `@stocks`, `@parameters`, `@init`,
`@equations`, and `@balances`; only `@time` is mandatory. Variables may use
arbitrary literal history references `[t-k]`. A scalar `@init` value means one
prior-period value; a vector is an oldest-to-newest `k`-period history. Missing
older history is zero-padded. Stocks are predetermined: their equations may
depend only on history and parameters, never current-period variables or
flows. Put current-flow relationships in the simultaneous equations instead.
Balances are evaluated independently for every simulated period. `sheets(sol,
t)` returns the filled sheets for period `t`; dynamic accounting returns
`(consistent, periods)` for all periods and one result for a selected period.

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
    stocks = Symbol[]
    stock_declarations = Dict{Symbol, String}()
    defaults = Dict{Symbol, Any}()
    eqs = Equation[]
    init = Dict{Symbol, Vector{Float64}}()
    balance_sheets = BalanceSheet[]

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
        elseif mac == Symbol("@stocks")
            _parse_stocks!(stocks, stock_declarations, blk, "$(__source__.file):$(__source__.line)")
        elseif mac == Symbol("@parameters")
            _parse_params!(params, defaults, blk)
        elseif mac == Symbol("@equations")
            _parse_equations!(eqs, blk)
        elseif mac == Symbol("@balances")
            ModelCore.parse_balances!(balance_sheets, blk)
        elseif mac == Symbol("@init")
            _parse_init!(init, blk)
        else
            error("Unknown dynamic @model block $mac. Valid blocks: @time, @variables, @stocks, @parameters, @init, @equations, @balances")
        end
    end

    time_expr === nothing && error("Dynamic @model requires a @time block, e.g. @time 0.0:1.0:100.0")

    _validate_time_indexing!(eqs)
    for bs in balance_sheets, rhs in values(bs.calculations)
        check_expr(rhs)
    end

    source = "$(__source__.file):$(__source__.line)"
    variable_names = [v.name for v in variables]
    unknown_stocks = [s for s in stocks if !(s in variable_names)]
    isempty(unknown_stocks) || error("Dynamic @model at $source: unknown @stocks declaration " *
        "$(first(unknown_stocks)) (`$(stock_declarations[first(unknown_stocks)])`; declaration must name a variable declared in @variables). " *
        "Declare it in @variables or remove it from @stocks.")
    raw_sheet_eqs = [Equation(:_sheet, rhs) for bs in balance_sheets for rhs in values(bs.calculations)]
    discovered_lags = _discover_lags(vcat(eqs, raw_sheet_eqs), variable_names)

    # A history entry is a value strictly before the first simulated period.
    # Warn only when the model actually needs more history than was supplied.
    for (name, depth) in _required_lag_depths(discovered_lags)
        history_length = length(get(init, name, Float64[]))
        warning_message = "Dynamic model at $source: $name requires history length $depth, " *
            "but @init provides $history_length. Add at least $depth oldest-to-newest " *
            "values to @init (missing older values are zero-padded)."
        depth > history_length && @warn warning_message
    end

    rewritten_for_validation = _rewrite_equations(eqs, Set(v.name for v in variables))
    ModelCore.validate_model(
        :dynamic, source, [v.name for v in variables], [p.name for p in params],
        rewritten_for_validation; discovered_lags=discovered_lags)

    rewritten_sheets = [BalanceSheet(bs.name, bs.fields, bs.assets, bs.liabilities,
        Dict(k => _rewrite_time_refs(v, Set(variable_names)) for (k, v) in bs.calculations))
        for bs in balance_sheets]
    ModelCore._sheet_order(rewritten_sheets,
        vcat(variable_names, [p.name for p in params], _required_lag_symbols(discovered_lags)), source)

    stockset = Set(stocks)
    for stock in stocks
        equation = only(eq for eq in rewritten_for_validation if
            (eq.lhs isa Symbol ? eq.lhs : eq.lhs.args[1]) == stock)
        found = Set{Symbol}()
        _collect_symbols!(found, equation.rhs)
        offending = sort!(collect(intersect(found, Set(variable_names))))
        isempty(offending) || error("Dynamic @model at $source: stock equation $(equation): " *
            "$stock is marked @stocks but its equation uses current-period values " *
            "($(join(string.(offending), ", "))). Stocks must be predetermined by history alone; " *
            "remove it from @stocks or reformulate (variables that depend on current flows stay in the simultaneous block).")
    end

    eval_fun = _generate_eval(variables, params, eqs)

    nulls = _generate_nulls(variables, params, eqs, stocks)
    stocks_eval = _generate_stocks_eval(variables, params, eqs, stocks)
    sheet_eval = ModelCore.generate_sheet_eval(rewritten_sheets, variable_names,
        [p.name for p in params]; lag_symbols=_required_lag_symbols(discovered_lags), source=source)

    # Default Newton initial guess: one value for each simultaneous flow.
    n = length(variables) - length(stocks)
    dynamic_parametrization = GlobalRef(@__MODULE__, :DynamicParametrization)
    dynamic_model = GlobalRef(@__MODULE__, :DynamicModel)
    discrete_time = GlobalRef(@__MODULE__, :DiscreteTime)

    return esc(
        quote
            $dynamic_parametrization(
                $dynamic_model(
                    $discrete_time(collect($time_expr)),
                    $variables,
                    $params,
                    $eqs,
                    $nulls,
                    $eval_fun,
                    $stocks,
                    $stocks_eval,
                    $balance_sheets,
                    $sheet_eval
                ),
                Dict{Symbol, Float64}($((:($(QuoteNode(k)) => $(v)) for (k, v) in defaults)...)),
                $init,
                ones($n),
            )
        end
    )
end


"""
    @scenario base begin
        parameter = value
        @equations begin
            variable[t] == replacement_rhs
        end
        @init begin
            variable = history
        end
    end

Create an independent dynamic scenario. Parameter assignments override declared
parameters. Entries in `@equations` replace base equations by their left-hand
side variable (`x[t]` and `x` both match `x`), while `@init` entries replace
only the named histories. Unmentioned parameters, equations, and histories are
deep-copied from the base. The derived residual, stock, evaluation, and balance
sheet closures are rebuilt; the base model is not mutated.

```julia
HighGrowth = @scenario Baseline begin
    growth = 0.03
    @equations begin
        K[t] == K[t - 1] + investment
    end
    @init begin
        K = [9.0, 10.0]
    end
end
```
"""
macro scenario(model, body)
    parameters, equation_block, init_block = ModelCore.parse_dynamic_scenario_entries(body)
    equation_pairs = Expr[]
    if !isnothing(equation_block)
        override_names = Set{Symbol}()
        for (lhs, rhs) in ModelCore.parse_equation_entries(equation_block)
            expression = Expr(:call, :(==), lhs, rhs)
            override_name = _scenario_lhs(Equation(lhs, rhs))
            override_name isa Symbol || error("Dynamic @scenario equation override has invalid LHS `$lhs` in source/offending equation `$expression`; fix or remove it.")
            override_name in override_names && error("Duplicate dynamic @scenario equation override LHS $override_name in source/offending equation `$expression`; set it once.")
            push!(override_names, override_name)
            push!(equation_pairs, :($(QuoteNode(Equation(lhs, rhs))) => $(QuoteNode(expression))))
        end
    end
    init_pairs = Expr[]
    init_names = Set{Symbol}()
    if !isnothing(init_block)
        init_block isa Expr && init_block.head == :block ||
            error("Dynamic @scenario @init must be a begin...end block, source/offending expression: $init_block")
        for line in init_block.args
            line isa LineNumberNode && continue
            line isa Expr && line.head == :(=) && length(line.args) == 2 && line.args[1] isa Symbol ||
                error("Dynamic @scenario @init entries must be `name = value`, source/offending expression: $line")
            name, value = line.args
            name in init_names && error("Duplicate dynamic @scenario @init name $name in source/offending expression `$line`; set each initializer once.")
            push!(init_names, name)
            push!(init_pairs, :($(QuoteNode(name)), $(value), $(QuoteNode(line))))
        end
    end
    param_pairs = [:(($(QuoteNode(name)), $(value), $(QuoteNode(Expr(:(=), name, value))))) for (name, value) in parameters]
    source = "$(__source__.file):$(__source__.line)"
    scenario_builder = GlobalRef(@__MODULE__, :_dynamic_scenario)
    return esc(quote
        $scenario_builder($model,
            [$(param_pairs...)],
            [$(equation_pairs...)],
            [$(init_pairs...)],
            $source)
    end)
end
