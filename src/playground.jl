using PKAssetPrices
Revise.retry()

sol = solve_model(PKAssetPrices.AssetPK2)
display_sheets(sol)

print(PKAssetPrices.AssetPK2)
PKAssetPrices.display_model(SimplePKModel())
PKAssetPrices.variable_descriptions(SimplePKModel())
PKAssetPrices.param_descriptions(SimplePKModel())
