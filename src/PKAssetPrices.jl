module PKAssetPrices


export Dashboard, Dynamic, Static, DynamicPlotting, StaticPlotting
export solve_model

function solve_model() end

include("base.jl")
include("static/static_model.jl")
include("dynamic/dynamic_model.jl")
include("dash/Dashboard.jl")
include("plotting/dynamic_plotting.jl")
include("plotting/static_plotting.jl")

function dashboard_models()
    return Dict{String, Static.Parametrization}(
        "Baseline" => Static.Baseline,
        "PQA" => Static.PQA,
        "PQC" => Static.PQC,
        "PQCr" => Static.PQCr,
        "PQCrDIFF" => Static.PQCrDIFF,
    )
end

dashboard_dynamic_models() = Dashboard.default_dynamic_models()

function @main(args)
    models = dashboard_models()
    dynamic_models = dashboard_dynamic_models()
    app = Dashboard.get_app(models, dynamic_models)
    Dashboard.register_callbacks!(app, models, dynamic_models)

    Dashboard.run(app)
    return 0
end


end # module PKAssetPrices
