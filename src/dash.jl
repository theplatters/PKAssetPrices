using PKAssetPrices

models = Dict("Q" => Static.AssetPKQ, "PQ" => Static.AssetPKPQ, "PQ2" => Static.AssetPKPQ2, "PQA" => Static.AssetPKPQ2A, "PQC"=> Static.AssetPKPQC, "PQCr"=> Static.AssetPKPQCr)
app = Dashboard.get_app(models)
Dashboard.register_callbacks!(app, models )

Dashboard.run(app)