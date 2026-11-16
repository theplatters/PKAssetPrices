function eval_curve(param::Parametrization, input::Dict{Symbol, Float64})
    return param.model.curve_eval(input, param.params)
end

function eval_curve(sol::Solution)
    return sol.model.model.curve_eval(sol.variables, sol.model.params)
end

function eval_curve(sol::Solution, variable, iter_range, curve)
    evaluated = Float64[]
    vars = copy(sol.variables)
    for item in iter_range
        vars[variable] = item
        push!(evaluated, sol.model.model.curve_eval(vars, sol.model.params)[curve])
    end
    return evaluated
end
