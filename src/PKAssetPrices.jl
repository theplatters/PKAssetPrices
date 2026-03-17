module PKAssetPrices


export Dashboard, Dynamic, Static
export solve_model

function solve_model() end

include("base.jl")
include("static/static_model.jl")
include("dynamic/dynamic_model.jl")
include("dash/Dashboard.jl")

function @main(args)
    models = Dict("PQ" => Static.AssetPKPQ, "PQA" => Static.AssetPKPQA, "PQC"=> Static.AssetPKPQC, "PQCr"=> Static.AssetPKPQCr, "PQCrDIFF"=> Static.AssetPKPQCrDIFF)
    app = Dashboard.get_app(models)
    Dashboard.register_callbacks!(app, models )

    Dashboard.run(app)
    return 0
end


end # module PKAssetPrices
