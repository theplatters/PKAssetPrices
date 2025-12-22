macro model(name, body)
    variables = Symbol[]
    var_descriptions = OrderedDict{Symbol, String}()
    parameters = OrderedDict{Symbol, Any}()
    param_descriptions = OrderedDict{Symbol, String}()
    equations = []
    curves = OrderedDict{Symbol, Any}()
    
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
    
    return esc(quote
        $param_struct
        $model_struct
        $get_nulls_func
        $(curve_funcs...)
        $helper_funcs
    end)
end

function generate_helpers(model_struct_name, variables, var_descriptions, parameters, param_descriptions)
  []
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
end

function parse_parameters!(parameters, descriptions, body)
    for line in body.args
        line isa LineNumberNode && continue
        
        if line isa Expr && line.head == :(=)
            lhs = line.args[1]
            rhs = line.args[2]
            
            # Check if lhs has a description
            if  rhs.head == :tuple
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
end

function parse_equations!(equations, body)
    for line in body.args
        line isa LineNumberNode && continue
        
        if line isa Expr && line.head == :call && line.args[1] == :(==)
            push!(equations, (lhs = line.args[2], rhs = line.args[3]))
        end
    end
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
end

function generate_param_struct(param_struct_name, parameters) 
    field_exprs = [:($(field)::Float64 = $(value)) for (field, value) in parameters]
    
    # Build the struct expression
    struct_expr = quote
        Base.@kwdef struct $param_struct_name <: AbstractPKModelParams
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
    
    quote
        function get_nulls(model::$model_name)
            return function (u, p::$param_name)
                (; $(param_syms...)) = p
                $var_tuple = u
                StaticArrays.SA[$(residuals...)]
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
