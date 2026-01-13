struct BalanceSheetAbstractData
    name::Symbol
    fields::Vector{Symbol}
    assets::Vector{Symbol}
    liabilities::Vector{Symbol}
    calculations::Dict{Symbol, Union{Symbol, Expr}}
end

"""
    @model name begin
        @variables begin
            var1 = "description"
            var2 = "description"
            ...
        end
        
        @parameters begin
            param1 = value, "description"
            param2 = value, "description"
            ...
        end
        
        @equations begin
            var1 == expression
            var2 == expression
            ...
        end
        
        @curves begin
            CurveName(arg) = expression
            ...
        end
        
        @balances begin
            @sheet SheetName begin
                @asset field1 = expression
                @liability field2 = expression
                ...
            end
        end
    end

Define a macroeconomic model with variables, parameters, equations, and balance sheets.

# Arguments
- `name::Symbol`: The name of the model (e.g., SimplePK2)

# Nested Macros

## @variables
Defines the endogenous variables of the model. Each variable can have a description.

**Example:**
```julia
@variables begin
    Y = "Output"
    N = "Employment"
    P = "Price level"
end
```

## @parameters
Defines the exogenous parameters and their default values. Each parameter requires a value and can have a description.
}
**Example:**
```julia
@parameters begin
    b = 0.5, "consumption rate"
    c = 0.8, "credit rationing"
    k = 0.3, "reserve share"
end
```

## @equations
Defines the equilibrium equations that must hold in the model. Uses equality (==) to specify relationships.

**Example:**
```julia
@equations begin
    Y == ND + c * D
    P == (1 + n) * a * W
    N == a * Y
end
```

## @curves
Defines special curves (e.g., IS, LM, AD, AS) as functions of variables for analysis.

**Example:**
```julia
@curves begin
    IS(r) = (1/(1-b)) * (c * (d₀ - d₁ * r))
    AD(P) = (1/(1-b)) * (c * (d₀ - d₁ * ((1 + m) * (i₀ + i₁ * P))))
end
```

## @balances
Defines balance sheets with assets and liabilities that must sum correctly.

**Example:**
```julia
@balances begin
    @sheet Bank begin
        @asset loans = dL
        @liability deposits = dM
    end
end
```

# Output
Generates:
- Parameter struct (`nameParams`): holds all parameters
- Model struct (`nameModel`): holds parameters and initial conditions
- Solution struct (`nameSolution`): holds solved variable values and balance sheets
- Functions for solving the model and computing curves

# Example
```julia
@model SimplePK2 begin
    @variables begin
        Y = "Output"
        N = "Employment"
    end
    
    @parameters begin
        b = 0.5, "consumption rate"
        a = 0.8, "production efficiency"
    end
    
    @equations begin
        Y == b * Y
        N == a * Y
    end
end

# Solve the model
sol = solve_model(SimplePK2Model())
println(sol.sol.Y)
```

See also: [`@scenario`](@ref)
"""
macro model(name, body)
    variables = Symbol[]
    var_descriptions = OrderedDict{Symbol, String}()
    parameters = OrderedDict{Symbol, Any}()
    param_descriptions = OrderedDict{Symbol, String}()
    equations = []
    curves = OrderedDict{Symbol, Any}()
    balanace_sheets = BalanceSheetAbstractData[]
    balanace_sheet_calculations = []

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
                parse_balances!(balanace_sheets, macro_body)
            end
        end
    end


    # Generate all the code
    param_struct_name = Symbol(name, "Params")
    model_struct_name = Symbol(name, "Model")

    param_struct = generate_param_struct(param_struct_name, parameters)
    model_struct = generate_model_struct(model_struct_name, param_struct_name, length(variables))
    get_nulls_func = generate_get_nulls(model_struct_name, param_struct_name, variables, parameters, equations)
    curve_funcs = generate_curves(curves, param_struct_name, parameters, name)
    helper_funcs = generate_helpers(model_struct_name, variables, var_descriptions, parameters, param_descriptions)
    balance_sheet_quoted = generate_balance_sheets(balanace_sheets, name)
    balance_sheet_functions = generate_balance_sheets_helper_methods(balanace_sheets, name, variables)


    solve_method = generate_solve_method(name, variables, balanace_sheets)
    return esc(
        quote
            $param_struct
            $model_struct
            $get_nulls_func
            $(curve_funcs...)
            $(balance_sheet_quoted...)
            $(balance_sheet_functions...)
            $solve_method
            $(helper_funcs...)
        end
    )
end


function generate_solve_method(name::Symbol, variables::Vector{Symbol}, balance_sheets::Vector{BalanceSheetAbstractData})
    sol_struct_name = Symbol(name, "Solution")
    sol_var_struct_name = Symbol(sol_struct_name, "Var")
    sol_sheets_struct_name = Symbol(sol_struct_name, "Sheets")
    modelname = Symbol(name, "Model")
    solution_fields = [:($(variable)::Float64) for variable in variables ]
    sol_sheets = [:(get_sheet($(Symbol(name, balance_sheet.name)), sol_var)) for balance_sheet in balance_sheets]
    @info solution_fields
    return quote
        struct $sol_var_struct_name
            $(solution_fields...)
        end

        struct $sol_struct_name
            sol::$sol_var_struct_name
            sheets::Vector{BalanceSheet}
        end


        function solve_model(md::$(modelname))
            sol = get_solution(md)

            sol_var = $(sol_var_struct_name)(sol.u...)
            sol_sheets = [$(sol_sheets...)]
            return $(sol_struct_name)(
                sol_var,
                sol_sheets
            )
        end
    end
end

function generate_helpers(model_struct_name, variables, var_descriptions, parameters, param_descriptions)
    display_model = quote
        function display_model(model::$model_struct_name)
            line = "="^60
            colw = 24  # width for the name column

            println("\n", line)
            println("Variables")
            println(line)

            for v in $variables
                desc = get($var_descriptions, v, "")
                println(rpad(string(v), colw), "  ", desc)
            end

            println("\n", line)
            println("Parameters")
            println(line)

            keys_params = collect(keys($parameters))
            for p in sort!(keys_params; by = string)
                desc = get($param_descriptions, p, "")
                println(rpad(string(p), colw), "  ", desc)
            end

            return nothing
        end
    end

    variable_des = quote
        function variable_descriptions(model::$model_struct_name)
            return $var_descriptions
        end
    end

    param_des = quote
        function param_descriptions(model::$model_struct_name)
            return $param_descriptions
        end
    end

    return [display_model, variable_des, param_des]
end


function parse_variables!(variables, descriptions, body)
    for line in body.args
        line isa LineNumberNode && continue

        if line isa Expr && line.head == :(=)
            var_name = line.args[1]
            var_desc = line.args[2]
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
            if rhs.head == :tuple
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
            push!(equations, (lhs = line.args[2], rhs = line.args[3]))
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
                curve_args = lhs.args[2:end]
                curves[curve_name] = (args = curve_args, body = rhs)
            end
        end
    end
    return
end

function parse_balance!(balance_sheets, body)

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
    return BalanceSheetAbstractData(
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

            balance_sheet = parse_balance!(balance_sheets, line)
            @info balance_sheet
            push!(balance_sheets, balance_sheet)
        end
    end
    return
end

function generate_param_struct(param_struct_name, parameters)
    field_exprs = [:($(field)::Float64 = $(value)) for (field, value) in parameters]

    # Build the struct expression
    struct_expr = quote
        Base.@kwdef struct $param_struct_name <: AbstractPKParams
            $(field_exprs...)
        end
    end

    return struct_expr
end

function generate_model_struct(model_name, param_struct_name, amount_of_variables)
    struct_expr = quote
        Base.@kwdef struct $model_name <: AbstractPKModel
            params::$param_struct_name = $param_struct_name()
            u0::SVector{$amount_of_variables, Float64} = ones(SVector{$amount_of_variables})
        end
    end
    return struct_expr
end

function generate_get_nulls(model_name, param_name, variables, parameters, equations)
    var_tuple = Expr(:tuple, variables...)
    param_syms = collect(keys(parameters))

    residuals = [:($(eq.lhs) - $((eq.rhs))) for eq in equations]

    return quote
        function get_nulls(model::$model_name)
            return function (u, p::$param_name)
                (; $(param_syms...)) = p
                $var_tuple = u
                return StaticArrays.SA[$(residuals...)]
            end
        end
    end
end

function generate_curves(curves, param_name, parameters, model_name)
    curve_funcs = []
    param_syms = collect(keys(parameters))

    for (name, curve_data) in curves
        args = curve_data.args
        body = curve_data.body

        cure_name = Symbol(model_name, name)
        func = quote
            function $(cure_name)($(args...), params::$param_name)
                (; $(param_syms...)) = params
                $body
            end
        end

        push!(curve_funcs, func)
    end

    return curve_funcs
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
macro scenario(name, body)
    params = Dict{Symbol, Float64}()
    for expr in body.args
        expr isa LineNumberNode && continue
        if expr.head == :(=)
            params[expr.args[1]] = expr.args[2]
        end
    end

    model_name = Symbol(name, "Model")
    params_name = Symbol(name, "Params")

    # Build the params call with keyword arguments
    params_call = Expr(:call, params_name)
    for (pk, pval) in params
        push!(params_call.args, Expr(:kw, pk, pval))
    end

    return esc(
        quote
            $(model_name)(
                params = $params_call
            )
        end
    )
end
