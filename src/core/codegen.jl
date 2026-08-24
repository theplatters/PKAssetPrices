"""Generate the common residual closure used by both model faces."""
function generate_residual_closure(variables, parameters, equations;
                                   lag_symbols=Symbol[])
    var_syms = [v isa Symbol ? v : v.name for v in variables]
    param_syms = [p isa Symbol ? p : p.name for p in parameters]
    var_tuple = Expr(:tuple, var_syms...)
    residuals = [:($(eq.lhs) - $((eq.rhs))) for eq in equations]

    return quote
        function (u, p)
            (; $(param_syms...), $(lag_symbols...)) = p
            $var_tuple = u
            return [$(residuals...)]
        end
    end
end
