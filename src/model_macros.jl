struct BalanceSheetAbstractData
    name::Symbol
    fields::Vector{Symbol}
    assets::Vector{Symbol}
    liabilities::Vector{Symbol}
    calculations::Dict{Symbol, Union{Symbol, Expr}}
end


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
    curve_funcs = generate_curves(curves, param_struct_name, parameters)
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
            $helper_funcs
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
    return []
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

function generate_curves(curves, param_name, parameters)
    curve_funcs = []
    param_syms = collect(keys(parameters))

    for (name, curve_data) in curves
        args = curve_data.args
        body = curve_data.body

        func = quote
            function $(name)($(args...), params::$param_name)
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
