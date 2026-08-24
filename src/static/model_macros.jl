"""
    Name = @model begin ... end

Define a static model and return its [`Parametrization`](@ref). The body
supports `@variables`, `@parameters`, and `@equations`, with optional
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
    curves = Curve[]
    balance_sheets = BalanceSheet[]

    # Parse the model body
    for expr in body.args
        expr isa LineNumberNode && continue

        if expr isa Expr && expr.head == :macrocall
            macro_name = expr.args[1]
            macro_body = expr.args[3]

            if macro_name == Symbol("@variables")
                parse_variables!(variables, var_descriptions, macro_body)
            elseif macro_name == Symbol("@parameters")
                parse_parameters!(parameters, param_descriptions, macro_body)
            elseif macro_name == Symbol("@equations")
                parse_equations!(equations, macro_body)
            elseif macro_name == Symbol("@curves")
                parse_curves!(curves, macro_body)
            elseif macro_name == Symbol("@balances")
                parse_balances!(balance_sheets, macro_body)
            end
        end
    end


    sort_equations_by_variables!(equations, variables)
    nulls = generate_get_nulls(variables, parameters, equations)
    curve_funcs = generate_curve_eval(curves, variables, parameters)


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
                ones($(length(variables)))
            )
        end
    )

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


function solve_model(model::Parametrization)::Static.Solution
    nulls! = model.model.nulls
    p = (; model.params...)   # OrderedDict/Dic -> NamedTuple
    prob = NonlinearProblem(nulls!, model.u0, p)
    sol = solve(prob)
    variables = Dict{Symbol, Float64}((v => sol.u[i] for (i, v) in enumerate(model.model.variables)))
    if !SciMLBase.successful_retcode(sol)
        @warn sol.retcode
        @warn "Model solution did not converge: $(sol.retcode)"
    end

    sheets = fill_balance_sheets(model, sol.u)
    return Solution(variables, model, sheets)
end


function parse_variables!(variables, descriptions, body)
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(=)
            var_name = line.args[1]
            var_desc = line.args[2]

            if var_name isa Expr && var_name.head == :(call)
                error("Only allowed in dynamic models")
            end
            push!(variables, var_name)
            descriptions[var_name] = var_desc
        elseif line isa Symbol
            # Just variable name
            push!(variables, line)
            descriptions[line] = ""
        end
    end
    return
end

function parse_parameters!(parameters, descriptions, body)
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(=)
            lhs = line.args[1]
            rhs = line.args[2]

            # Check if lhs has a description
            if rhs isa Expr && rhs.head == :tuple
                # Pattern: param  = value, "description"
                param_name = lhs
                param_desc = rhs.args[2]
                parameters[param_name] = rhs.args[1]
                descriptions[param_name] = param_desc
            else
                # Pattern: param = value
                parameters[lhs] = rhs
                descriptions[lhs] = ""
            end
        end
    end
    return
end

function parse_equations!(equations, body)
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :call && line.args[1] == :(==)
            push!(equations, Equation(line.args[2], line.args[3]))
        end
    end
    return
end

function parse_curves!(curves, body)
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(=)
            lhs = line.args[1]
            rhs = line.args[2]

            if lhs isa Expr && lhs.head == :call
                curve_name = lhs.args[1]
                curve_args = lhs.args[2]
                push!(curves, Curve(curve_name, curve_args, rhs))
            end
        end
    end
    return
end

function parse_balance!(body)

    balance_sheet_name = body.args[3]
    balance_sheet_body = body.args[4]
    fields = Symbol[]
    assets = Symbol[]
    liabilities = Symbol[]
    equations = Dict{Symbol, Union{Expr, Symbol}}()

    for line in balance_sheet_body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(macrocall)
            is_liability = line.args[1] == Symbol("@liability")
            is_asset = line.args[1] == Symbol("@asset")
            if !(is_liability || is_asset)
                error("Value is neither asset nor liability")
            end

            field_name = line.args[3].args[1]
            is_liability && push!(liabilities, field_name)
            is_asset && push!(assets, field_name)

            push!(fields, field_name)
            equations[field_name] = line.args[3].args[2]

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
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(macrocall) && line.args[1] == Symbol("@sheet")

            balance_sheet = parse_balance!(line)
            push!(balance_sheets, balance_sheet)
        end
    end
    return
end


function generate_get_nulls(variables, parameters, equations)
    var_tuple = Expr(:tuple, variables...)
    param_syms = collect(keys(parameters))

    residuals = [:($(eq.lhs) - $((eq.rhs))) for eq in equations]

    return quote
        function (u, p)
            (; $(param_syms...)) = p
            $var_tuple = u
            return [$(residuals...)]
        end
    end
end


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


function generate_balance_sheets(balance_sheets, model_name)
    balance_sheet_quoted = Expr[]
    for balance_sheet in balance_sheets

        balance_sheet_name = Symbol(model_name, balance_sheet.name)
        push!(
            balance_sheet_quoted, quote
                struct $balance_sheet_name <: BalanceSheet
                    $(balance_sheet.fields...)
                end
            end
        )
    end
    return balance_sheet_quoted
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
    for ex in body.args
        ex isa LineNumberNode && continue
        if ex isa Expr && ex.head == :(=)
            push!(assigns, :(params[$(QuoteNode(ex.args[1]))] = $(ex.args[2])))
        end
    end

    return esc(
        quote
            local m = $model
            local params = copy(m.params)   # copy if you don't want to mutate the model
            $(assigns...)
            Parametrization(m.model, params, m.u0)  # note: no "&" in Julia
        end
    )
end
