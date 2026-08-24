"""
    Name = @model begin ... end

Define a static model and return its [`Parametrization`](@ref). The body
supports `@variables`, `@parameters`, `@init`, and `@equations`, with optional
`@curves` and `@balances` blocks. A balance block contains `@sheet` blocks,
which in turn contain `@asset` and `@liability` entries.

```julia
Example = @model begin
    @variables begin
        Y = "output"
        C = "consumption"
    end
    @parameters begin
        c = 0.8, "consumption share"
        G = 0.4, "autonomous spending"
    end
    @init begin
        Y = 1.0
        C = 1.0
    end
    @equations begin
        Y == C
        C == c * Y + G
    end
    @curves begin
        demand(Y) = c * Y + G
    end
    @balances begin
        @sheet Household begin
            @asset wealth = Y
            @liability equity = Y
        end
    end
end
```

See also: [`@scenario`](@ref).
"""
macro model(body)
    variables = Symbol[]
    var_descriptions = Dict{Symbol, String}()
    parameters = Dict{Symbol, Float64}()
    param_descriptions = Dict{Symbol, String}()
    equations = Equation[]
    variable_names = Symbol[]
    parameter_names = Symbol[]
    init_names = Symbol[]
    init_values = Dict{Symbol, Float64}()
    curves = Curve[]
    balance_sheets = BalanceSheet[]

    # Parse the model body
    for expr in body.args
        expr isa LineNumberNode && continue

        expr isa Expr && expr.head == :macrocall ||
            error("Invalid static @model entry (expected a macro block): $expr")
        length(expr.args) == 3 || error("Malformed static macro block: $expr")
        macro_name = expr.args[1]
        macro_body = expr.args[3]

        if macro_name == Symbol("@variables")
            parse_variables!(variables, var_descriptions, macro_body; declaration_names=variable_names)
        elseif macro_name == Symbol("@parameters")
            parse_parameters!(parameters, param_descriptions, macro_body; declaration_names=parameter_names)
        elseif macro_name == Symbol("@init")
            parse_init!(init_values, init_names, macro_body)
        elseif macro_name == Symbol("@equations")
            parse_equations!(equations, macro_body)
        elseif macro_name == Symbol("@curves")
            parse_curves!(curves, macro_body)
        elseif macro_name == Symbol("@balances")
            parse_balances!(balance_sheets, macro_body)
        else
            error("Unknown static @model block $macro_name. Valid blocks: @variables, @parameters, @init, @equations, @curves, @balances")
        end
    end


    source = "$(__source__.file):$(__source__.line)"
    ModelCore.validate_model(:static, source, variable_names, parameter_names, equations)
    label = "static @model at $source"
    duplicate_init = unique(v for v in init_names if count(==(v), init_names) > 1)
    isempty(duplicate_init) || error(
        "$label: duplicate @init variable(s): $(join(duplicate_init, ", ")). " *
        "Initialize each variable at most once.")
    unknown_init = [v for v in init_names if !(v in variable_names)]
    isempty(unknown_init) || error(
        "$label: @init names not declared as variables: $(join(unique(unknown_init), ", ")). " *
        "Declare the variable or remove the initializer.")
    sort_equations_by_variables!(equations, variables)
    nulls = generate_get_nulls(variables, parameters, equations)
    curve_funcs = generate_curve_eval(curves, variables, parameters)


    u0_values = [get(init_values, variable, 1.0) for variable in variables]
    return esc(
        quote
            Parametrization(
                Model(
                    $variables,
                    $(collect(keys(parameters))),
                    $var_descriptions,
                    $param_descriptions,
                    $equations,
                    $curves,
                    $curve_funcs,
                    $nulls,
                    $balance_sheets
                ),
                $parameters,
                $(u0_values)
            )
        end
    )

end

function _numeric_literal(value)
    value isa Real && !(value isa Bool) && return Float64(value)
    if value isa Expr && value.head == :call && length(value.args) == 2 &&
            value.args[1] in (:+, :-)
        value.args[2] isa Real && !(value.args[2] isa Bool) || return nothing
        return Float64(value.args[1] == :+ ? value.args[2] : -value.args[2])
    end
    return nothing
end

function parse_init!(values::Dict{Symbol, Float64}, names::Vector{Symbol}, body)
    body isa Expr && body.head == :block ||
        error("Expected a begin...end block for @init, got: $body")
    for line in body.args
        line isa LineNumberNode && continue
        line isa Expr && line.head == :(=) && length(line.args) == 2 ||
            error("Invalid @init entry (expected `variable = numeric_literal`): $line")
        name, value_expr = line.args
        name isa Symbol || error("@init variable name must be a Symbol in: $line")
        value = _numeric_literal(value_expr)
        isnothing(value) && error("@init value must be a numeric literal in: $line")
        push!(names, name)
        values[name] = value
    end
    return
end

"Evaluate a Symbol/Expr/Number given variable values and parameter values."
function _eval_calc(x, vars::Dict{Symbol, Float64}, params::Dict{Symbol, Float64})
    if x isa Number
        return Float64(x)
    elseif x isa Symbol
        if haskey(vars, x)
            return vars[x]
        end
        if haskey(params, x)
            return params[x]
        end
        error("Unknown symbol in balance sheet calculation: $x")
    elseif x isa Expr
        # Evaluate expression in a local scope with bindings from vars/params
        # (simple, but uses eval; OK if expressions are trusted and module-scoped)
        assigns = Any[
            :($(k) = $(v)) for (k, v) in vars
        ]
        append!(
            assigns, Any[
                :($(k) = $(v)) for (k, v) in params
            ]
        )

        return Base.eval(
            @__MODULE__, quote
                let
                    $(assigns...)
                    $(x)
                end
            end
        ) |> Float64
    else
        error("Unsupported calc type: $(typeof(x))")
    end
end

function fill_balance_sheets(model::Parametrization, sol_u::AbstractVector{<:Real})
    # solved variables dict
    vars = Dict{Symbol, Float64}(
        model.model.variables[i] => Float64(sol_u[i])
            for i in eachindex(model.model.variables)
    )
    params = model.params

    filled = BalanceSheetFilled[]
    for bs in model.model.balance_sheets
        # compute all calculations once
        calcvals = Dict{Symbol, Float64}()
        for (name, expr) in bs.calculations
            calcvals[name] = _eval_calc(expr, vars, params)
        end

        assets = Pair{Symbol, Float64}[]
        for a in bs.assets
            v = haskey(calcvals, a) ? calcvals[a] : _eval_calc(a, vars, params)
            push!(assets, a => v)
        end

        liabilities = Pair{Symbol, Float64}[]
        for l in bs.liabilities
            v = haskey(calcvals, l) ? calcvals[l] : _eval_calc(l, vars, params)
            push!(liabilities, l => v)
        end

        push!(filled, BalanceSheetFilled(bs.name, assets, liabilities))
    end
    return filled
end


function sort_equations_by_variables!(equations::Vector{Equation}, variables::Vector{Symbol})
    varpos = Dict{Symbol, Int}(v => i for (i, v) in pairs(variables))

    # (optional) only enforce that LHS are Symbols and are declared variables
    for eq in equations
        eq.lhs isa Symbol || error("Equation LHS must be a Symbol, got: $(eq.lhs)")
        haskey(varpos, eq.lhs) || error("Equation LHS $(eq.lhs) not declared in @variables")
    end

    # stable sort => duplicates stay next to each other, preserving original order
    sort!(equations; by = eq -> varpos[eq.lhs], alg = Base.Sort.MergeSort)
    return equations
end


function _static_model_label(model::Model)
    for name in names(@__MODULE__, all = true, imported = false)
        isdefined(@__MODULE__, name) || continue
        value = getfield(@__MODULE__, name)
        value isa Parametrization && value.model === model && return string(name)
    end
    return "Static.Model"
end

function solve_model(model::Parametrization; alg=nothing, abstol=nothing, reltol=nothing,
                     maxiters=nothing, strict::Bool=true, u0=nothing)::Static.Solution
    initial = if isnothing(u0)
        copy(model.u0)
    else
        u0 isa AbstractVector || error("Static.solve_model u0 must be a vector")
        length(u0) == length(model.model.variables) ||
            error("Static.solve_model u0 length $(length(u0)) does not match $(length(model.model.variables)) variables")
        all(x -> x isa Real, u0) || error("Static.solve_model u0 must contain only real values")
        Float64.(collect(u0))
    end
    nulls! = model.model.nulls
    p = isempty(model.params) ? nothing : (; model.params...)   # OrderedDict/Dict -> NamedTuple
    prob = NonlinearProblem(nulls!, initial, p)
    options = (; (name => value for (name, value) in
        ((:abstol => abstol), (:reltol => reltol), (:maxiters => maxiters))
        if !isnothing(value))...)
    sol = if isnothing(alg)
        isempty(options) ? solve(prob) : solve(prob; options...)
    else
        solve(prob, alg; options...)
    end
    variables = Dict{Symbol, Float64}((v => sol.u[i] for (i, v) in enumerate(model.model.variables)))
    residual = nulls!(sol.u, p)
    max_residual = isempty(residual) ? 0.0 : maximum(abs, residual)
    label = _static_model_label(model.model)
    if !SciMLBase.successful_retcode(sol)
        message = "$label failed with retcode $(sol.retcode), max residual $(max_residual)"
        strict ? error(message) : @warn(message)
    end

    sheets = fill_balance_sheets(model, sol.u)
    return Solution(variables, model, sheets, sol.retcode, max_residual)
end


function parse_variables!(variables, descriptions, body; declaration_names=Symbol[])
    for (var_name, var_desc) in ModelCore.parse_variable_entries(
            body)
        push!(variables, var_name)
        push!(declaration_names, var_name)
        descriptions[var_name] = var_desc
    end
    return
end

function parse_parameters!(parameters, descriptions, body; declaration_names=Symbol[])
    for (name, value_desc) in ModelCore.parse_parameter_entries(body)
        value, desc = value_desc
        parameters[name] = value
        push!(declaration_names, name)
        descriptions[name] = desc
    end
    return
end

function parse_equations!(equations, body)
    for (lhs, rhs) in ModelCore.parse_equation_entries(body)
        push!(equations, Equation(lhs, rhs))
    end
    return
end

function parse_curves!(curves, body)
    body isa Expr && body.head == :block || error("Expected a begin...end block for @curves, got: $body")
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(=) && length(line.args) == 2
            lhs = line.args[1]
            rhs = line.args[2]

            lhs isa Expr && lhs.head == :call && length(lhs.args) == 2 &&
                lhs.args[1] isa Symbol && lhs.args[2] isa Symbol ||
                error("Invalid curve entry (expected `name(argument) = expression`): $line")
            push!(curves, Curve(lhs.args[1], lhs.args[2], rhs))
        else
            error("Invalid curve entry (expected `name(argument) = expression`): $line")
        end
    end
    return
end

function parse_balance!(body)
    body isa Expr && body.head == :macrocall && length(body.args) == 4 ||
        error("Malformed @sheet block: $body")
    body.args[1] == Symbol("@sheet") || error("Expected @sheet, got: $body")
    balance_sheet_name = body.args[3]
    balance_sheet_body = body.args[4]
    balance_sheet_name isa Symbol || error("@sheet name must be a Symbol in: $body")
    balance_sheet_body isa Expr && balance_sheet_body.head == :block ||
        error("@sheet $balance_sheet_name must contain a begin...end block")
    fields = Symbol[]
    assets = Symbol[]
    liabilities = Symbol[]
    equations = Dict{Symbol, Union{Expr, Symbol}}()

    for line in balance_sheet_body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(macrocall) && length(line.args) == 3
            is_liability = line.args[1] == Symbol("@liability")
            is_asset = line.args[1] == Symbol("@asset")
            if !(is_liability || is_asset)
                error("Unknown @sheet entry (expected @asset or @liability): $line")
            end

            assignment = line.args[3]
            assignment isa Expr && assignment.head == :(=) && length(assignment.args) == 2 ||
                error("Malformed asset/liability entry: $line")
            field_name = assignment.args[1]
            field_name isa Symbol || error("Asset/liability name must be a Symbol in: $line")
            assignment.args[2] isa Union{Expr, Symbol} ||
                error("Asset/liability value must be an expression or Symbol in: $line")
            is_liability && push!(liabilities, field_name)
            is_asset && push!(assets, field_name)

            push!(fields, field_name)
            equations[field_name] = assignment.args[2]

        elseif line isa LineNumberNode
            continue
        else
            error("Invalid @sheet entry (expected @asset or @liability): $line")
        end
    end
    return BalanceSheet(
        balance_sheet_name,
        fields,
        assets,
        liabilities,
        equations
    )
end

function parse_balances!(balance_sheets, body)
    body isa Expr && body.head == :block || error("Expected a begin...end block for @balances, got: $body")
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(macrocall) && length(line.args) == 4 && line.args[1] == Symbol("@sheet")

            balance_sheet = parse_balance!(line)
            push!(balance_sheets, balance_sheet)
        elseif line isa LineNumberNode
            continue
        else
            error("Invalid @balances entry (expected @sheet): $line")
        end
    end
    return
end


generate_get_nulls(variables, parameters, equations) =
    ModelCore.generate_residual_closure(variables, collect(keys(parameters)), equations)


function generate_curve_eval(curves, variables, parameters)
    param_syms = collect(keys(parameters))

    isempty(curves) && return quote
        function (u::AbstractDict{Symbol, <:Real}, p)
            return nothing
        end
    end

    # Pull variables out of the dict: S = u[:S], I = u[:I], ...
    var_assigns = [:($(v) = u[$(QuoteNode(v))]) for v in variables]

    assigns = [:($(c.name) = $(c.body)) for c in curves]
    fields = [:($(c.name) = $(c.name)) for c in curves]

    return quote
        function (u::AbstractDict{Symbol, <:Real}, p)
            (; $(param_syms...)) = NamedTuple(p)
            $(var_assigns...)
            $(assigns...)
            return (; $(fields...))
        end
    end
end


"""
    @scenario name begin
        param1 = value
        param2 = value
        ...
    end

Create a specific scenario of a previously defined model with custom parameter values.

The scenario macro allows you to quickly instantiate a model with modified parameters without 
having to manually create the parameter struct. The base model is inferred from the given name.

# Arguments
- `name::Symbol`: The base model name (without "Model" suffix, e.g., SimplePK2)
- `body`: Block containing parameter assignments

# Returns
An instance of `nameModel` with the specified parameters and default initial conditions.

# Example
```julia
# First define a model
@model SimplePK2 begin
    @parameters begin
        b = 0.5, "consumption rate"
        c = 0.8, "credit rationing"
    end
    # ... other model components ...
end

# Create scenario 1 with modified b parameter
scen1 = @scenario SimplePK2 begin
    b = 0.6
end

# Create scenario 2 with multiple modified parameters
scen2 = @scenario SimplePK2 begin
    b = 0.7
    c = 0.85
end

# Solve both scenarios
sol1 = solve_model(scen1)
sol2 = solve_model(scen2)
```

# See Also
- [`@model`](@ref): Define a model
- [`solve_model`](@ref): Solve an instantiated model
"""
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
            local params = copy(m.params)   # copy if you don't want to mutate the model
            $(assigns...)
            Parametrization(m.model, params, copy(m.u0))  # note: no "&" in Julia
        end
    )
end
