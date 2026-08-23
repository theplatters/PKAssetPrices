#!/usr/bin/env julia
#=# -*- coding: utf-8 -*-
#=╔══════════════════════════════════════════════════════════════╗
#=║  Mathematica-style equilibrium panel for Baseline model     ║
#=║  Produces a 2×2 composite figure matching the look of       ║
#=║  graphtest-money.nb (purple/orange, percentage ticks, ...)  ║
#=╚══════════════════════════════════════════════════════════════╝

using PKAssetPrices
using PKAssetPrices.Static: Baseline, solve_model, eval_curve
using CairoMakie
using Printf

# ── 1. Color palette (Mathematica-style) ─────────────────────────────────
# Curve colours
const CURVE_COLOR   = RGBf(0.5, 0.0, 0.5)   # purple – IS, AD, asset demand
const SUPPLY_COLOR  = RGBf(1.0, 0.5, 0.0)   # orange – IR, AS, asset supply
const COUNTERFACT   = (CURVE_COLOR, 0.38)   # faded purple for dashed IR

# Balance-sheet colours (Mathematica notebook palette)
const BS_ASSET      = RGBf(0.20, 0.59, 0.86)   # blue
const BS_LIABILITY  = RGBf(0.84, 0.25, 0.30)   # red
const BS_ASSET_LT   = RGBf(0.35, 0.72, 0.93)   # light blue (reserves as asset)
const BS_LIAB_LT    = RGBf(0.92, 0.50, 0.55)   # light red  (CB credit as liab)

# ── 2. Helpers (matching Mathematica's style) ────────────────────────────
const FONT_SIZE   = 20
const TITLE_SIZE  = 26
const LEGEND_SIZE = 20
const PLOT_RANGES = (
    IS_IR_X = (4.0, 10.0),
    IS_IR_Y = (0.06, 0.15),
    AD_AS_X = (5.0, 9.0),
    AD_AS_Y = (0.9, 2.5),
    AM_X    = (0.6, 1.3),
    AM_Y    = (0.7, 1.5),
)

# Percentage-axis tick formatter
function pct_ticks(plot_range)
    vals = collect(plot_range)
    labels = [@sprintf("%d%%", round(Int, 100 * v)) for v in vals]
    return (vals, labels)
end

# ── 3. Solve model ───────────────────────────────────────────────────────
solution = solve_model(Baseline)
vars   = solution.variables
Y_eq   = vars[:Y]
r_eq   = vars[:r]
P_eq   = vars[:P]
AP_eq  = vars[:AP]
AE_eq  = vars[:AE]

# ── 4. Build figure (2×2 layout) ────────────────────────────────────────
fig = Figure(
    size = (1400, 1000),
    fontsize = FONT_SIZE,
    figure_padding = (28, 38, 28, 28),
    backgroundcolor = :white,
)

# ─────────────────── Panel A: Goods Market Dynamics (IS/IR) ──────────────
ax1 = Axis(
    fig[1, 1];
    title = rich("(A) ", "Goods Market Dynamics"; font = :bold),
    xlabel = "Output Y",
    ylabel = "interest rate r",
    xgridcolor = ( :black, 0.12 ),
    ygridcolor = ( :black, 0.12 ),
    titlesize = TITLE_SIZE,
    xlabelsize = FONT_SIZE,
    ylabelsize = FONT_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
    xticks = LinearTicks(4),
    yticks = pct_ticks(0.06:0.02:0.14),
)

# IS curve: r → Y
r_range = range(PLOT_RANGES.IS_IR_Y...; length = 200)
is_Y = map(r_range) do r
    v = copy(vars); v[:r] = r
    eval_curve(solution.model, v).IS
end
lines!(ax1, is_Y, r_range; color = CURVE_COLOR, linewidth = 3, label = "IS")

# IR curve: Y → r
y_range1 = range(PLOT_RANGES.IS_IR_X...; length = 200)
ir_r = map(y_range1) do y
    v = copy(vars); v[:Y] = y
    eval_curve(solution.model, v).IR
end
lines!(ax1, y_range1, ir_r; color = SUPPLY_COLOR, linewidth = 3, label = "IR")

# Dashed counterfactual IR (lower i₀)
lower_model = let
    p = copy(solution.model.params)
    p[:i0] *= 0.0   # i₀ → 0
    PKAssetPrices.Static.Parametrization(solution.model.model, p, copy(solution.model.u0))
end
lower_ir_r = map(y_range1) do y
    v = copy(vars); v[:Y] = y
    eval_curve(lower_model, v).IR
end
lines!(ax1, y_range1, lower_ir_r;
    color = COUNTERFACT, linewidth = 2, linestyle = :dash, label = "IR (lower i₀)")

xlims!(ax1, PLOT_RANGES.IS_IR_X...)
ylims!(ax1, PLOT_RANGES.IS_IR_Y...)
axislegend(ax1; position = :rb, framevisible = false, labelsize = LEGEND_SIZE,
    labelsize = LEGEND_SIZE)

# ─────────────────── Panel B: AD/AS (Output and Inflation Dynamics) ─────
ax2 = Axis(
    fig[1, 2];
    title = rich("(B) ", "Output and Inflation Dynamics"; font = :bold),
    xlabel = "Output Y",
    ylabel = "Price Level P",
    xgridcolor = ( :black, 0.12 ),
    ygridcolor = ( :black, 0.12 ),
    titlesize = TITLE_SIZE,
    xlabelsize = FONT_SIZE,
    ylabelsize = FONT_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
)

# AD curve: P → Y
p_range = range(PLOT_RANGES.AD_AS_Y...; length = 200)
ad_Y = map(p_range) do p
    v = copy(vars); v[:P] = p
    eval_curve(solution.model, v).ADc
end
lines!(ax2, ad_Y, p_range; color = CURVE_COLOR, linewidth = 3, label = "AD")

# AS curve: Y → P
y_range2 = range(PLOT_RANGES.AD_AS_X...; length = 200)
as_P = map(y_range2) do y
    v = copy(vars); v[:Y] = y
    eval_curve(solution.model, v).ASc
end
lines!(ax2, y_range2, as_P; color = SUPPLY_COLOR, linewidth = 3, label = "AS")

# Dashed AD (lower i₀) for counterfactual
lower_ad_Y = map(p_range) do p
    v = copy(vars); v[:P] = p
    eval_curve(lower_model, v).ADc
end
lines!(ax2, lower_ad_Y, p_range;
    color = (CURVE_COLOR, 0.38), linewidth = 2, linestyle = :dash,
    label = "AD (lower i₀)")

# Equilibrium reference lines
vlines!(ax2, [Y_eq]; color = (:black, 0.20), linestyle = :dot, linewidth = 1.5)
hlines!(ax2, [P_eq]; color = (:black, 0.20), linestyle = :dot, linewidth = 1.5)
scatter!(ax2, [Y_eq], [P_eq]; color = :black, markersize = 12,
    strokecolor = :white, strokewidth = 2)

xlims!(ax2, PLOT_RANGES.AD_AS_X...)
ylims!(ax2, PLOT_RANGES.AD_AS_Y...)
axislegend(ax2; position = :rb, framevisible = false, labelsize = LEGEND_SIZE)

# ─────────────────── Panel C: Financial Market Dynamics (Asset Market) ───
ax3 = Axis(
    fig[2, 1];
    title = rich("(C) ", "Financial Market Dynamics"; font = :bold),
    xlabel = "Base-price-equivalent quantity",
    ylabel = "Asset Price AP",
    xgridcolor = ( :black, 0.12 ),
    ygridcolor = ( :black, 0.12 ),
    titlesize = TITLE_SIZE,
    xlabelsize = FONT_SIZE,
    ylabelsize = FONT_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
)

# Asset demand curve (AMD): AP → quantity
ap_range = range(PLOT_RANGES.AM_X...; length = 200)
amd_Q = map(ap_range) do ap
    v = copy(vars); v[:AP] = ap
    eval_curve(solution.model, v).AMD
end
lines!(ax3, amd_Q, ap_range; color = CURVE_COLOR, linewidth = 3,
    label = "Asset Demand")

# Asset supply (AMS): constant
ams_Q = map(ap_range) do ap
    v = copy(vars); v[:AP] = ap
    eval_curve(solution.model, v).AMS
end
lines!(ax3, ams_Q, ap_range; color = SUPPLY_COLOR, linewidth = 3,
    label = "Asset Supply")

# Counterfactual demand (lower i₀)
lower_solution = solve_model(lower_model)
lower_amd_Q = map(ap_range) do ap
    v = copy(lower_solution.variables); v[:AP] = ap
    eval_curve(lower_model, v).AMD
end
lines!(ax3, lower_amd_Q, ap_range;
    color = (CURVE_COLOR, 0.38), linewidth = 2, linestyle = :dash,
    label = "Demand (lower i₀)")

# Equilibrium point
curves_eq = eval_curve(solution)
Q_eq = (curves_eq.AMD + curves_eq.AMS) / 2
vlines!(ax3, [Q_eq]; color = (:black, 0.20), linestyle = :dot, linewidth = 1.5)
hlines!(ax3, [AP_eq]; color = (:black, 0.20), linestyle = :dot, linewidth = 1.5)
scatter!(ax3, [Q_eq], [AP_eq]; color = :black, markersize = 12,
    strokecolor = :white, strokewidth = 2)

xlims!(ax3, PLOT_RANGES.AM_X...)
ylims!(ax3, PLOT_RANGES.AM_Y...)
axislegend(ax3; position = :rt, framevisible = false, labelsize = LEGEND_SIZE)

# ─────────────────── Panel D: Sector Balance Sheets ──────────────────────
ax4 = Axis(
    fig[2, 2];
    title = "Sector Balance Sheets",
    ylabel = "Amount",
    xgridvisible = false,
    ygridcolor = (:black, 0.08),
    titlesize = TITLE_SIZE,
    xlabelsize = FONT_SIZE,
    ylabelsize = FONT_SIZE,
    bottomspinecolor = :black,
    topspinecolor = :black,
    leftspinecolor = :black,
    rightspinecolor = :black,
)

# Build balance-sheet bar data (same logic as static_plotting.jl)
dL_val = vars[:dL]
dM_val = vars[:dM]
dR_val = vars[:dR]

# Colour mapping following Mathematica graphtest-money.nb
# Blue (#3366CC) for assets, red (#D6404D) for liabilities
# Light variants for reserves (asset) and CB credit (liability)

# Positions: 6 bars (3 sectors × 2 sides)
positions  = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
bar_groups = Int[1, 2, 3, 3, 4, 4, 5, 6]  # stack group per segment
bar_heights = [dM_val, dL_val, dL_val, dR_val, dM_val, dR_val, dR_val, dR_val]
bar_colors  = [
    BS_ASSET,       # 1: PS Assets – deposits
    BS_LIABILITY,   # 2: PS Liabilities – loans
    BS_ASSET,       # 3a: Bank Assets – loans
    BS_ASSET_LT,    # 3b: Bank Assets – reserves
    BS_LIABILITY,   # 4a: Bank Liabilities – deposits
    BS_LIAB_LT,     # 4b: Bank Liabilities – CB credit
    BS_ASSET,       # 5: CB Assets – CB credit
    BS_LIABILITY,   # 6: CB Liabilities – reserves
]

barplot!(ax4, [1, 2, 3, 3, 4, 4, 5, 6], bar_heights;
    stack = bar_groups, width = 0.82, color = bar_colors,
    strokecolor = (:black, 0.65), strokewidth = 1.5,
    bar_labels = [
        "Deposits\n$(round(dM_val; sigdigits=4))",
        "Loans\n$(round(dL_val; sigdigits=4))",
        "Loans\n$(round(dL_val; sigdigits=4))",
        "Reserves\n$(round(dR_val; sigdigits=4))",
        "Deposits\n$(round(dM_val; sigdigits=4))",
        "CB Credit\n$(round(dR_val; sigdigits=4))",
        "CB Credit\n$(round(dR_val; sigdigits=4))",
        "Reserves\n$(round(dR_val; sigdigits=4))",
    ],
    label_position = :center, label_color = :black, label_size = 14,
)

hlines!(ax4, [0.0]; color = (:black, 0.55), linewidth = 1.5)

# Sector labels (bold, above bars)
max_y = max(dM_val, dL_val + dR_val) * 1.18
text!(ax4, [1.5, 3.5, 5.5], fill(max_y * 0.90, 3);
    text = ["Private Sector", "Banks", "Central Bank"],
    align = (:center, :bottom), font = :bold, fontsize = TITLE_SIZE,
    color = :black)

# Annotation text (reserve ratio, total loans, risk indicator)
rr = dR_val / dM_val
risk = get(vars, :SD, 0.0) / dL_val
annotation = join([
    @sprintf("Reserve ratio: %.4f", rr),
    @sprintf("Total loans: %.4f", dL_val),
    @sprintf("Risk indicator: %.4f", risk),
], '\n')
text!(ax4, 0.98, 0.50; text = annotation, space = :relative,
    align = (:right, :center), fontsize = FONT_SIZE, color = :black)

tick_labels = [
    "Assets\nPrivate\nSector",
    "Liabilities\nPrivate\nSector",
    "Assets\nBanks",
    "Liabilities\nBanks",
    "Assets\nCentral\nBank",
    "Liabilities\nCentral\nBank",
]
ax4.xticks = (positions, tick_labels)
xlims!(ax4, 0.3, 6.7)
ylims!(ax4, 0.0, max_y)

# ── 5. Layout adjustments & save ─────────────────────────────────────────
colgap!(fig.layout, 42)
rowgap!(fig.layout, 22)
rowsize!(fig.layout, 1, Relative(0.50))
rowsize!(fig.layout, 2, Relative(0.50))

# ── 6. Output ────────────────────────────────────────────────────────────
output_dir = normpath(joinpath(@__DIR__, "..", "plots"))
mkpath(output_dir)

pdf_path = joinpath(output_dir, "baseline_mathematica_style.pdf")
png_path = joinpath(output_dir, "baseline_mathematica_style.png")

save(pdf_path, fig)
println("Saved: $pdf_path")
save(png_path, fig)
println("Saved: $png_path")

println("\n── Equilibrium values ──")
println(@sprintf("Y  = %.4f", Y_eq))
println(@sprintf("r  = %.4f", r_eq))
println(@sprintf("P  = %.4f", P_eq))
println(@sprintf("AP = %.4f", AP_eq))
println(@sprintf("AE = %.4f", AE_eq))
println(@sprintf("dL = %.4f, dM = %.4f, dR = %.4f", dL_val, dM_val, dR_val))
println(@sprintf("SD = %.4f", vars[:SD]))
println(@sprintf("Reserve ratio = %.4f", rr))
println(@sprintf("Risk indicator = %.4f", risk))