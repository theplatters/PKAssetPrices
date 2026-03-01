module PKAssetPrices


export Dynamic, Static, Dashboard
export solve_model

function solve_model() end

include("base.jl")
include("static/static_model.jl")
include("dynamic/dynamic_model.jl")
include("dash/Dashboard.jl")


end # module PKAssetPrices
