using PKAssetPrices.Static: Baseline, FirmsRation, PQC, PQCr, PQCrDIFF, SimplePK, solve_model
using CSV
using DataFrames
using PKAssetPrices


function risk_indicator(sol::Static.Solution)
  bank_liabilities = Iterators.filter(
    x -> x.sector_name == :Banks, sol.sheets
  ) |> first
  return Static.liabilities(bank_liabilities) / sol.Y

end

function (@main)(ARGS)
  default_output_dir = normpath(joinpath(@__DIR__, "..", "output"))
  output_dir = isempty(ARGS) ? default_output_dir : abspath(first(ARGS))
  mkpath(output_dir)


  asset_market_models = (
    ("simplepk", SimplePK),
    ("baseline", Baseline),
    ("pqc", PQC),
    ("pqcr", PQCr),
    ("pqcrdiff", PQCrDIFF),
    ("firmsration", FirmsRation),
  )

  results = DataFrame(model=String[], risk_indicator=Float64[])
  for (name, model) in asset_market_models
    solution = solve_model(model)
    indicator = risk_indicator(solution)
    push!(results, (model=name, risk_indicator=indicator))
    @info "Calculated risk indicator" model=name risk_indicator=indicator
  end

  output_path = joinpath(output_dir, "risk_indicators.csv")
  CSV.write(output_path, results)
  println("Saved risk indicators to $output_path")

  return 0


end
