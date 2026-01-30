using PKAssetPrices.Static: @model, AssetPK2, solve_model
Revise.retry()

sol = solve_model(AssetPK2)
Static.display_sheets(sol)

print(PKAssetPrices.AssetPK2)
PKAssetPrices.display_model(SimplePKModel())
PKAssetPrices.variable_descriptions(SimplePKModel())
PKAssetPrices.param_descriptions(SimplePKModel())
