using PKAssetPrices
using PKAssetPrices.Static: Baseline, solve_model, eval_curve
using CairoMakie
using Printf

# ── 1. Color palette (Mathematica-style) ─────────────────────────────────
# Curve colours
const CURVE_COLOR = RGBf(0.5, 0.0, 0.5)   # purple – IS, AD, asset demand
const SUPPLY_COLOR = RGBf(1.0, 0.5, 0.0)   # orange – IR, AS, asset supply
const COUNTERFACT = (CURVE_COLOR, 0.38)   # faded purple for dashed IR

# Balance-sheet colours — matching curve palette (purple = assets, orange = liabilities)
const BS_ASSET = CURVE_COLOR     # purple for assets
const BS_LIABILITY = SUPPLY_COLOR    # orange for liabilities

# ── 2. Helpers (matching Mathematica's style) ────────────────────────────
const FONT_SIZE = 20
const TITLE_SIZE = 26
const LEGEND_SIZE = 20
const PLOT_RANGES = (
  IS_IR_X=(4.0, 10.0),
  IS_IR_Y=(0.06, 0.15),
  AD_AS_X=(5.0, 9.0),
  AD_AS_Y=(1.2, 2.2),
  AM_X=(0.6, 1.3),
  AM_Y=(0.7, 1.3),
)

# Percentage-axis tick formatter
function pct_ticks(plot_range)
  vals = collect(plot_range)
  labels = [@sprintf("%d%%", round(Int, 100 * v)) for v in vals]
  return (vals, labels)
end

# ── 3. Solve model ───────────────────────────────────────────────────────
solution = solve_model(Baseline)
vars = solution.variables
Y_eq = vars[:Y]
r_eq = vars[:r]
P_eq = vars[:P]
AP_eq = vars[:AP]
AE_eq = vars[:AE]

# ── 4. Build figure (2×2 layout) ────────────────────────────────────────
fig = Figure(
  size=(1400, 1000),
  fontsize=FONT_SIZE,
  figure_padding=(28, 38, 28, 28),
  backgroundcolor=:white,
)

# ─────────────────── Panel A: Goods Market Dynamics (IS/IR) ──────────────
ax1 = Axis(
  fig[1, 1];
  title=rich("(A) ", "Goods Market Dynamics"; font=:bold),
  xlabel="Output Y",
  ylabel="interest rate r",
  xgridcolor=(:black, 0.12),
  ygridcolor=(:black, 0.12),
  titlesize=TITLE_SIZE,
  xlabelsize=FONT_SIZE,
  ylabelsize=FONT_SIZE,
  bottomspinecolor=:black,
  topspinecolor=:black,
  leftspinecolor=:black,
  rightspinecolor=:black,
  xticks=LinearTicks(4),
  yticks=pct_ticks(0.06:0.02:0.14),
)

# IS curve: r → Y
r_range = range(PLOT_RANGES.IS_IR_Y...; length=200)
is_Y = map(r_range) do r
  v = copy(vars)
  v[:r] = r
  eval_curve(solution.model, v).IS
end
lines!(ax1, is_Y, r_range; color=CURVE_COLOR, linewidth=3, label="IS")

# IR curve: Y → r
y_range1 = range(PLOT_RANGES.IS_IR_X...; length=200)
ir_r = map(y_range1) do y
  v = copy(vars)
  v[:Y] = y
  eval_curve(solution.model, v).IR
end
lines!(ax1, y_range1, ir_r; color=SUPPLY_COLOR, linewidth=3, label="IR")

# Dashed counterfactual IR (lower i₀)
lower_model = let
  p = copy(solution.model.params)
  p[:i0] *= 0.0   # i₀ → 0
  PKAssetPrices.Static.Parametrization(solution.model.model, p, copy(solution.model.u0))
end
lower_ir_r = map(y_range1) do y
  v = copy(vars)
  v[:Y] = y
  eval_curve(lower_model, v).IR
end
lines!(
  ax1, y_range1, lower_ir_r;
  color=COUNTERFACT, linewidth=2, linestyle=:dash, label="IR (lower i₀)"
)

xlims!(ax1, PLOT_RANGES.IS_IR_X...)
ylims!(ax1, PLOT_RANGES.IS_IR_Y...)
# Inline labels (no legend box) — relative coordinates guarantee inside chart
text!(
  ax1, 0.08, 0.08; text="IS", space=:relative,
  color=CURVE_COLOR, fontsize=LEGEND_SIZE, align=(:left, :bottom)
)
text!(
  ax1, 0.88, 0.88; text="IR", space=:relative,
  color=SUPPLY_COLOR, fontsize=LEGEND_SIZE, align=(:right, :top)
)
text!(
  ax1, 0.88, 0.72; text="IR (lower i₀)", space=:relative,
  color=COUNTERFACT, fontsize=LEGEND_SIZE - 2, align=(:right, :top)
)

# ─────────────────── Panel B: AD/AS (Output and Inflation Dynamics) ─────
ax2 = Axis(
  fig[1, 2];
  title=rich("(B) ", "Output and Inflation Dynamics"; font=:bold),
  xlabel="Output Y",
  ylabel="Price Level P",
  xgridcolor=(:black, 0.12),
  ygridcolor=(:black, 0.12),
  titlesize=TITLE_SIZE,
  xlabelsize=FONT_SIZE,
  ylabelsize=FONT_SIZE,
  bottomspinecolor=:black,
  topspinecolor=:black,
  leftspinecolor=:black,
  rightspinecolor=:black,
)

# AD curve: P → Y
p_range = range(PLOT_RANGES.AD_AS_Y...; length=200)
ad_Y = map(p_range) do p
  v = copy(vars)
  v[:P] = p
  eval_curve(solution.model, v).ADc
end
lines!(ax2, ad_Y, p_range; color=CURVE_COLOR, linewidth=3, label="AD")

# AS curve: Y → P
y_range2 = range(PLOT_RANGES.AD_AS_X...; length=200)
as_P = map(y_range2) do y
  v = copy(vars)
  v[:Y] = y
  eval_curve(solution.model, v).ASc
end
lines!(ax2, y_range2, as_P; color=SUPPLY_COLOR, linewidth=3, label="AS")

# Dashed AD (lower i₀) for counterfactual
lower_ad_Y = map(p_range) do p
  v = copy(vars)
  v[:P] = p
  eval_curve(lower_model, v).ADc
end
lines!(
  ax2, lower_ad_Y, p_range;
  color=(CURVE_COLOR, 0.38), linewidth=2, linestyle=:dash,
  label="AD (lower i₀)"
)

xlims!(ax2, PLOT_RANGES.AD_AS_X...)
ylims!(ax2, PLOT_RANGES.AD_AS_Y...)
# Inline labels (no legend box) — relative coordinates, at chart borders
text!(
  ax2, 0.08, 0.88; text="AD", space=:relative,
  color=CURVE_COLOR, fontsize=LEGEND_SIZE, align=(:left, :top)
)
text!(
  ax2, 0.08, 0.72; text="AD (lower i₀)", space=:relative,
  color=(CURVE_COLOR, 0.38), fontsize=LEGEND_SIZE - 2, align=(:left, :top)
)
text!(
  ax2, 0.88, 0.88; text="AS", space=:relative,
  color=SUPPLY_COLOR, fontsize=LEGEND_SIZE, align=(:right, :top)
)

# ─────────────────── Panel C: Financial Market Dynamics (Asset Market) ───
ax3 = Axis(
  fig[2, 1];
  title=rich("(C) ", "Financial Market Dynamics"; font=:bold),
  xlabel="Base-price-equivalent quantity",
  ylabel="Asset Price AP",
  xgridcolor=(:black, 0.12),
  ygridcolor=(:black, 0.12),
  titlesize=TITLE_SIZE,
  xlabelsize=FONT_SIZE,
  ylabelsize=FONT_SIZE,
  bottomspinecolor=:black,
  topspinecolor=:black,
  leftspinecolor=:black,
  rightspinecolor=:black,
)

# Asset demand curve (AMD): AP → quantity
ap_range = range(PLOT_RANGES.AM_X...; length=200)
amd_Q = map(ap_range) do ap
  v = copy(vars)
  v[:AP] = ap
  eval_curve(solution.model, v).AMD
end
lines!(
  ax3, amd_Q, ap_range; color=CURVE_COLOR, linewidth=3,
  label="Asset Demand"
)

# Asset supply (AMS): constant
ams_Q = map(ap_range) do ap
  v = copy(vars)
  v[:AP] = ap
  eval_curve(solution.model, v).AMS
end
lines!(
  ax3, ams_Q, ap_range; color=SUPPLY_COLOR, linewidth=3,
  label="Asset Supply"
)

# Counterfactual demand (lower i₀)
lower_solution = solve_model(lower_model)
lower_amd_Q = map(ap_range) do ap
  v = copy(lower_solution.variables)
  v[:AP] = ap
  eval_curve(lower_model, v).AMD
end
lines!(
  ax3, lower_amd_Q, ap_range;
  color=(CURVE_COLOR, 0.38), linewidth=2, linestyle=:dash,
  label="Demand (lower i₀)"
)

xlims!(ax3, PLOT_RANGES.AM_X...)
ylims!(ax3, PLOT_RANGES.AM_Y...)
# Inline labels (no legend box) — relative coordinates, at chart borders
text!(
  ax3, 0.08, 0.88; text="Asset Demand", space=:relative,
  color=CURVE_COLOR, fontsize=LEGEND_SIZE - 1, align=(:left, :top)
)
text!(
  ax3, 0.08, 0.68; text="Demand (lower i₀)", space=:relative,
  color=(CURVE_COLOR, 0.38), fontsize=LEGEND_SIZE - 3, align=(:left, :top)
)
text!(
  ax3, 0.88, 0.88; text="Asset Supply", space=:relative,
  color=SUPPLY_COLOR, fontsize=LEGEND_SIZE - 1, align=(:right, :top)
)

# ─────────────────── Panel D: Sector Balance Sheets ──────────────────────
ax4 = Axis(
  fig[2, 2];
  title=rich("(D) ", "Sector Balance Sheets"; font=:bold),
  ylabel="Amount",
  xgridvisible=false,
  ygridcolor=(:black, 0.08),
  titlesize=TITLE_SIZE,
  xlabelsize=FONT_SIZE,
  ylabelsize=FONT_SIZE,
  bottomspinecolor=:black,
  topspinecolor=:black,
  leftspinecolor=:black,
  rightspinecolor=:black,
)

# Balance-sheet values
dL_val = vars[:dL]
dM_val = vars[:dM]
dR_val = vars[:dR]

# 8 bar segments (3 sectors, with Banks stacked: Loans+Reserves, Deposits+CB credit)
positions = [1.0, 2.0, 4.0, 4.0, 5.0, 5.0, 7.0, 8.0]
bar_vals = [dM_val, dL_val, dL_val, dR_val, dM_val, dR_val, dR_val, dR_val]
bar_clrs = [BS_ASSET, BS_LIABILITY, BS_ASSET, BS_ASSET, BS_LIABILITY, BS_LIABILITY, BS_ASSET, BS_LIABILITY]
bar_stck = Int[1, 2, 3, 3, 4, 4, 5, 6]
bar_lbls = [
  @sprintf("D: %.1f", dM_val),
  @sprintf("L: %.1f", dL_val),
  @sprintf("L: %.1f", dL_val),
  @sprintf("R: %.1f", dR_val),
  @sprintf("D: %.1f", dM_val),
  @sprintf("CB: %.1f", dR_val),
  @sprintf("CB: %.1f", dR_val),
  @sprintf("R: %.1f", dR_val),
]

barplot!(
  ax4, positions, bar_vals;
  stack=bar_stck, width=0.8, color=bar_clrs,
  strokecolor=(:black, 0.65), strokewidth=1.5,
  bar_labels=bar_lbls,
  label_position=:center, label_color=:black, label_size=14,
)

hlines!(ax4, [0.0]; color=(:black, 0.55), linewidth=1.5)

# Sector separator lines
vlines!(ax4, [3.0, 6.0]; color=(:black, 0.35), linewidth=1.0, linestyle=:dash)

# Indicator text in top-right corner
risk = get(vars, :SD, 0.0) / dL_val
annotation = join(
  [
    @sprintf("Total Debt / GDP: %.2f", dL_val / Y_eq),
    @sprintf("Speculative debt / Total Debt: %.2f", risk),
  ], '\n'
)
text!(
  ax4, 0.97, 0.97; text=annotation, space=:relative,
  align=(:right, :top), fontsize=FONT_SIZE - 2, color=(:black, 0.75)
)

# Sector labels (smaller, below the indicators)
text!(
  ax4, [1.5, 4.5, 7.5], fill(5.5, 3);
  text=["Private Sector", "Banks", "Central Bank"],
  align=(:center, :bottom), font=:bold, fontsize=FONT_SIZE,
  color=:black
)

# x-ticks: alternating Assets / Liabilities
ax4.xticks = (positions, ["Assets", "Liabilities", "Assets", "Liabilities", "Assets", "Liabilities"])
xlims!(ax4, 0.3, 8.7)
ylims!(ax4, 0.0, 6.0)

# ── 5. Layout adjustments & save ─────────────────────────────────────────
colgap!(fig.layout, 42)
rowgap!(fig.layout, 22)
rowsize!(fig.layout, 1, Relative(0.5))
rowsize!(fig.layout, 2, Relative(0.5))

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
println(@sprintf("dL = %.2f, dM = %.2f, dR = %.2f", dL_val, dM_val, dR_val))
println(@sprintf("SD = %.2f", vars[:SD]))
println(@sprintf("Risk indicator = %.2f", risk))

