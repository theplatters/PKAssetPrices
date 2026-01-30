module BaseModels
export AbstractModel
abstract type AbstractModel end

struct Equation
    lhs::Union{Symbol, Expr}
    rhs::Union{Expr, Symbol, Number}
end

end
