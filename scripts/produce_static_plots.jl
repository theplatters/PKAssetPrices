using PKAssetPrices.Static: SimplePK, solve_model
using CairoMakie
using PKAssetPrices


function (@main)(ARGS)
    sol = solve_model(SimplePK)
    # A narrower canvas keeps labels legible when scaled to an A4 text block.
    fig = StaticPlotting.panel(sol; size = (1200, 720))
    default_output = normpath(
        joinpath(@__DIR__, "..", "plots", "simplepk_equilibrium_panel.pdf"),
    )
    output_path = isempty(ARGS) ? default_output : abspath(first(ARGS))
    mkpath(dirname(output_path))
    save(output_path, fig)
    println("Saved static equilibrium panel to $output_path")

    return 0


end
