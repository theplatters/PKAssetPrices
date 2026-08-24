using PKAssetPrices
using PKAssetPrices.Static: Baseline, solve_model, eval_curve
using DataFrames
using CSV
using Printf

# ── 1. Solve the Baseline model ───────────────────────────────────────────
solution = solve_model(Baseline)
println("Model solved. Variables:")
for (k, v) in sort!(collect(solution.variables); by = first)
  println("  $k = $v")
end

output_dir = normpath(joinpath(@__DIR__, "..", "output"))
mkpath(output_dir)

# ── 2. IS‑IR curves ───────────────────────────────────────────────────────
# Same ranges as in plot_is_lm (static_plotting.jl)
rate_range = range(0.05, 0.15; length = 200)
output_range_isir = range(3.0, 12.0; length = 200)

is_rates = Float64[]
is_outputs = Float64[]
ir_outputs = Float64[]
ir_rates = Float64[]

# IS curve: for each r → Y
for r in rate_range
  vars = copy(solution.variables)
  vars[:r] = r
  curves = eval_curve(solution.model, vars)
  push!(is_rates, r)
  push!(is_outputs, curves.IS)
end

# IR curve: for each Y → r
for y in output_range_isir
  vars = copy(solution.variables)
  vars[:Y] = y
  curves = eval_curve(solution.model, vars)
  push!(ir_outputs, y)
  push!(ir_rates, curves.IR)
end

df_isir = DataFrame(
  interest_rate = is_rates,
  output_IS = is_outputs,
)
df_ir = DataFrame(
  output = ir_outputs,
  interest_rate_IR = ir_rates,
)
CSV.write(joinpath(output_dir, "is_ir_curves.csv"), df_isir)
CSV.write(joinpath(output_dir, "ir_curves.csv"), df_ir)
println("Saved is_ir_curves.csv and ir_curves.csv")

# ── 3. AD‑AS curves ───────────────────────────────────────────────────────
# Same ranges as in plot_ad_as
price_range = range(0.5, 2.5; length = 200)
output_range_adas = range(4.5, 9.0; length = 200)

ad_prices = Float64[]
ad_outputs = Float64[]
as_outputs = Float64[]
as_prices = Float64[]

# AD curve: for each P → Y
for p in price_range
  vars = copy(solution.variables)
  vars[:P] = p
  curves = eval_curve(solution.model, vars)
  push!(ad_prices, p)
  push!(ad_outputs, curves.ADc)
end

# AS curve: for each Y → P
for y in output_range_adas
  vars = copy(solution.variables)
  vars[:Y] = y
  curves = eval_curve(solution.model, vars)
  push!(as_outputs, y)
  push!(as_prices, curves.ASc)
end

df_ad = DataFrame(
  price_level = ad_prices,
  output_AD = ad_outputs,
)
df_as = DataFrame(
  output = as_outputs,
  price_level_AS = as_prices,
)
CSV.write(joinpath(output_dir, "ad_as_curves.csv"), df_ad)
CSV.write(joinpath(output_dir, "as_curves.csv"), df_as)
println("Saved ad_as_curves.csv and as_curves.csv")

# ── 4. Asset‑market curves ────────────────────────────────────────────────
# Same range computation as in plot_asset_market
AP_eq = solution.variables[:AP]
price_endpoints = iszero(AP_eq) ? (-1.0, 1.0) : sort((0.55 * AP_eq, 1.8 * AP_eq))
asset_price_range = range(first(price_endpoints), last(price_endpoints); length = 200)

amd_prices = Float64[]
amd_quantities = Float64[]
ams_prices = Float64[]
ams_quantities = Float64[]

for ap in asset_price_range
  vars = copy(solution.variables)
  vars[:AP] = ap
  curves = eval_curve(solution.model, vars)
  push!(amd_prices, ap)
  push!(amd_quantities, curves.AMD)
  push!(ams_prices, ap)
  push!(ams_quantities, curves.AMS)
end

df_amd = DataFrame(
  asset_price = amd_prices,
  demand_at_base_price = amd_quantities,
)
df_ams = DataFrame(
  asset_price = ams_prices,
  asset_supply = ams_quantities,
)
CSV.write(joinpath(output_dir, "asset_demand_curve.csv"), df_amd)
CSV.write(joinpath(output_dir, "asset_supply_curve.csv"), df_ams)
println("Saved asset_demand_curve.csv and asset_supply_curve.csv")

# ── 5. Balance‑sheet data ─────────────────────────────────────────────────
# Using the same logic as balance_sheet_plot_data
bs_rows = []
for sheet in solution.sheets
  sector_name = string(sheet.sector_name)
  for (side, entries) in ((:asset, sheet.assets), (:liability, sheet.liabilities))
    for (name, value) in entries
      push!(bs_rows, Dict(
        "sector" => sector_name,
        "side" => string(side),
        "instrument" => string(name),
        "value" => value,
        "abs_value" => abs(value),
      ))
    end
  end
end
df_bs = DataFrame(bs_rows)
CSV.write(joinpath(output_dir, "balance_sheets.csv"), df_bs)
println("Saved balance_sheets.csv")

# ── 6. Equilibrium point data for reference ──────────────────────────────
df_eq = DataFrame(
  variable = collect(keys(solution.variables)),
  value = collect(values(solution.variables)),
)
CSV.write(joinpath(output_dir, "equilibrium_values.csv"), df_eq)
println("Saved equilibrium_values.csv")

println("\nAll CSVs written to $(output_dir)/")