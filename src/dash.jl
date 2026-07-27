using PKAssetPrices

models = PKAssetPrices.dashboard_models()
app = Dashboard.get_app(models)
Dashboard.register_callbacks!(app, models )

Dashboard.run(app)
