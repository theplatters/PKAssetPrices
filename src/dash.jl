using PKAssetPrices

models = PKAssetPrices.dashboard_models()
dynamic_models = PKAssetPrices.dashboard_dynamic_models()
app = Dashboard.get_app(models, dynamic_models)
Dashboard.register_callbacks!(app, models, dynamic_models)

Dashboard.run(app)
