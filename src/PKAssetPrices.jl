module PKAssetPrices

export Static, StaticPlotting, solve_model

function solve_model() end

include("base.jl")
include("static/static_model.jl")
include("plotting/static_plotting.jl")

end # module PKAssetPrices
