module BaseModels
export AbstractModel
import Base: show
abstract type AbstractModel end

struct Equation
    lhs::Union{Symbol, Expr}
    rhs::Union{Expr, Symbol, Number}
end

function Base.string(e::Equation)
    return "$(e.lhs) == $(e.rhs)"
end

function show(io::IO, e::Equation)
    show(io, "$(e.lhs) == $(e.rhs)")
    return nothing
end

function show(io::IO, ::MIME"text/plain", e::Equation)
    return show(io, e)
end

end
