using PKAssetPrices.Static: @model, AssetPK
using PKAssetPrices
Revise.retry()


Static.AssetPK.model


max_len = length.([m.variables, m.parameters, m.equations]) |> maximum
data = reduce(hcat, Static.pad_to.([m.variables, m.parameters, m.equations], max_len, nothing))

sol = solve_model(Static.AssetPK2)
sol


AssetPK.model.curve_eval(2 .* AssetPK.u0, AssetPK.params)


d = Dict(:a => 4, :b => 3)
d


print(PKAssetPrices.AssetPK2)
PKAssetPrices.display_model(SimplePKModel())
PKAssetPrices.variable_descriptions(SimplePKModel())
PKAssetPrices.param_descriptions(SimplePKModel())
