using PKAssetPrices

models = Dict("PQ" => Static.AssetPKPQ, "PQA" => Static.AssetPKPQA, "PQC"=> Static.AssetPKPQC, "PQCr"=> Static.AssetPKPQCr, "PQCrDIFF"=> Static.AssetPKPQCrDIFF)
app = Dashboard.get_app(models)
Dashboard.register_callbacks!(app, models )

Dashboard.run(app)
