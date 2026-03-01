using PKAssetPrices


models = Dict("Q" => Static.AssetPKQ, "PQ" => Static.AssetPKPQ)
app = Dashboard.get_app(models)
Dashboard.register_callbacks!(app, models )

Dashboard.run(app)
