module ModelCore

export AbstractModel, Equation

include("ast.jl")
include("parse.jl")
include("codegen.jl")
include("validate.jl")

end
