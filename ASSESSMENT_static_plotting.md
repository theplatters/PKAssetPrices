---
title: "Assessment of the static-plot automation versus notebooks (2)-(5)"
author: calculato
date: 2026-08-29
tags: [julia, makie, plotting, assetmarkets, assessment]
project: PKAssetPrices
---

This document assesses `scripts/produce_static_plots.jl` and
`src/plotting/static_plotting.jl` against the four single-purpose reference
notebooks `notebooks/(2)plot_assetmarket.ipynb` through
`notebooks/(5)plot_firmsration.ipynb`. The notebooks are treated as the source
of truth: the automation should produce byte-for-byte equivalent figures.

The comparison was done by extracting every code cell from the four notebooks
and reading `static_plotting.jl` / `produce_static_plots.jl` in full. The
equilibrium math (curve construction, counterfactual re-solving, reference
lines) is **already correct**; the divergences are all in colour, line style,
label text/placement, and the balance-sheet panel layout.

# Executive summary

The automation reproduces the *structure* of the notebooks (2x2 panel, same axis
titles, same curves, same reference/counterfactual logic) but diverges in
concrete, fixable ways. The most visible problems are:

- The IS/IR panel has its curve colours **swapped** relative to the notebooks.
- `FirmsRation` is run with `lower_i0_factor = 0.8`, but every notebook sets the
  counterfactual policy rate to `i0 = 0.0` absolutely (i.e. factor `0.0`).
- The counterfactual curves are drawn faded (`alpha = 0.38`) whereas the
  notebooks draw them at full opacity (dashed only).
- The balance-sheet panel (Panel D) is built with a **generic bar routine** that
  does not match the notebooks' hand-placed 8-bar layout (width, gaps, stacking,
  separators, sector labels, title text).
- The inline-label engine only supports *relative* coordinates, but the notebooks
  place the IS/IR labels in *data* coordinates and use a boxed `textlabel!` for
  one reference label.

A prioritised fix list with concrete patches follows in the next sections.

# How the automation is structured

`produce_static_plots.jl` is a thin driver. For each model it calls
`StaticPlotting.panel(solution, panel_type; ...)`, where `panel_type` is either
`StandardPanel` (no asset market; balance sheet spans the bottom row, labelled
"C") or `AssetMarketPanel` (asset market at `[2,1]`, balance sheet at `[2,2]`,
labelled "D"). All four notebooks use the `AssetMarketPanel` layout.

`static_plotting.jl` builds each panel from a `PlotSpecsBuilder`, then draws
inline labels from a `Dict{String, LabelSpec}`. The driver passes
`is_ir_label_positions`, `ad_as_label_positions`, `asset_market_label_positions`
dictionaries that override label *positions* (but not coordinate space, align,
font size, or box style).

Reference (baseline) and counterfactual (lower `i0`) curves are driven by
`reference_solution` and `lower_i0_factor`. `lower_autonomous_policy_rate`
multiplies the autonomous-rate parameter by `lower_i0_factor`.

# What already matches

These were verified by reading both sides and confirmed to be consistent:

- Curve math: IS/IR vary `r`/`Y`; AD/AS vary `P`/`Y`; asset market varies `AP`.
  Identical to the notebooks.
- Counterfactual re-solving: `solve_model(lower_model)` then sweep, matches the
  notebooks' `lower_sol = solve_model(lower_model)` pattern.
- AD/AS and asset-market curve colours (purple demand / orange supply) already
  match the notebooks.
- Reference (grey) colour `RGBf(0.45,0.45,0.45)` matches the notebooks'
  `BASELINE_COLOR`.
- Risk / total-debt annotation text matches.
- Figure size, padding, `colgap!`/`rowgap!` match (row sizes differ slightly, see
  below).

# Discrepancy register

| ID | Severity | Location | Notebook behaviour | Automation behaviour |
|----|----------|----------|--------------------|----------------------|
| D1 | Blocking | `static_plotting.jl:431-432` (`plot_is_ir`) | IS = orange, IR = purple | IS = purple, IR = orange (swapped) |
| D2 | Blocking | `produce_static_plots.jl:158` | counterfactual `i0 = 0.0` absolute | `FirmsRation` run with `lower_i0_factor = 0.8` |
| D3 | Blocking | `static_plotting.jl:12` `COUNTERFACTUAL` | counterfactual full opacity, `linewidth = 3`, dashed | `alpha = 0.38`, `linewidth = 2` |
| D4 | Blocking | `static_plotting.jl:506-507, 575-576` | reference dashed labels `"AD (lower i0)"`, `"AMD (base, lower i0)"` | labels `"AD (base lower i0)"`, `"Demand (base lower i0)"`; asset ref solid labelled `"Demand (base)"` vs notebook `"Asset Demand (base)"` |
| D5 | Blocking | `static_plotting.jl:661-719` + `:588-644` | 8-bar hand layout, `width = 1.2`, `inner_gap = 1.2`, `group_gap = 1.6`, stacked Banks/CB, separators `[3.1, 5.9]`, sector labels at `[1.7, 4.5, 7.3]` y `5.2`, title "Balance Sheet Analysis" | generic bar routine, `width = 0.8`, uniform `1.0` spacing, no stacking, separators `[3.0, 6.0]`, sector labels y `5.5`, title "Changes in Balance Sheets" |
| D6 | Fidelity | label engine (`reposition_labels`, `plot_curve_label!`) | IS/IR labels in *data* space; others relative; per-label align/size | only *relative* space; fixed `space = :relative` |
| D7 | Fidelity | `static_plotting.jl:756` (`_asset_market_axis`) | Panel C x-label "Quantity of assets traded" | x-label "Base-price-equivalent quantity" |
| D8 | Fidelity | `static_plotting.jl:768` (`_balance_axis`) | "(D) Balance Sheet Analysis" | "(D) Changes in Balance Sheets" |
| D9 | Fidelity | `static_plotting.jl:450-451` | default ticks | forces `percentage_ticks()` and `LinearTicks(4)` on IS/IR |
| D10 | Cosmetic | `static_plotting.jl:731,743,755,768` | axis titles not bold | axis titles `rich(..., font = :bold)` |
| D11 | Cosmetic | `static_plotting.jl:785-786` (`_set_gaps!`) | `rowsize!` `0.48` / `0.52` | `rowsize!` `0.5` / `0.5` |
| D12 | Cosmetic | `produce_static_plots.jl:69` | baseline exported as `baseline_mathematica_style.pdf` | exported as `baseline_equilibrium_panel.pdf` |
| D13 | Fidelity | `static_plotting.jl:507` (AD/AS), `:576` (asset) | grey dashed reference label drawn with boxed `textlabel!` at `(0.35, 0.45)` (notebooks 3-5) | plain `text!`, no box, different position |

# Recommended changes

The fixes are grouped by priority. Priority 1 and 2 are localised and low-risk.
Priority 3 is a small refactor of the label engine that is required only if you
want the IS/IR inline labels and the boxed reference label placed exactly as in
the notebooks.

## Priority 1: colour and counterfactual fixes

### D1 - swap IS/IR colours

In `plot_is_ir` (`static_plotting.jl`), the IS and IR colours are reversed
relative to the notebooks. The notebooks draw IS in orange and IR in purple;
`AD`/`AS` and asset demand/supply already use purple/orange consistently, so only
the two IS/IR calls must change.

```julia
# static_plotting.jl  (inside plot_is_ir, build_plot_specs do-block)
x_curve!(builder, "IS", :IS, :r, sol; color = IR_COLOR)   # notebook: IS is orange
y_curve!(builder, "IR", :IR, :Y, sol; color = IS_COLOR)   # notebook: IR is purple
```

The inline label colour follows the curve colour automatically, so this also
corrects the "IS"/"IR" label colours.

### D2 - FirmsRation counterfactual factor

Every notebook sets the counterfactual rate to `i0 = 0.0` absolutely. With
`lower_autonomous_policy_rate` multiplying by `factor`, that only reproduces when
`factor = 0.0`. Change the driver:

```julia
# produce_static_plots.jl  (model_panel_specs)
("firmsration", FirmsRation, 0.0, firmsration_label_positions),
```

Note: as written, the counterfactual of *all* four notebooks is `i0 = 0.0`, so
every entry in `model_panel_specs` should use `0.0`. The `lower_i0_factor`
mechanism is still useful if you later want a partial shock, but it does not
match the current notebooks at `0.8`.

### D3 - counterfactual opacity and width

The notebooks draw every counterfactual (purple, dashed, `linewidth = 3`) at full
opacity. Change the shared constant:

```julia
# static_plotting.jl
const COUNTERFACTUAL = IS_COLOR   # full-opacity purple, dashed (matches notebooks)
```

Then set the IS/IR counterfactual width to `3` (it currently inherits `2` from the
`COUNTERFACTUAL` usage at line 440-443). Because `COUNTERFACTUAL` is now a plain
colour, pass the width explicitly:

```julia
y_curve!(builder, "IR (lower i0)", :IR, :Y, lower_rate_solution;
         color = IS_COLOR, linewidth = 3, linestyle = :dash)
```

The AD/AS and asset-market counterfactual calls already pass `linewidth = 3`,
`linestyle = :dash` and will pick up the full-opacity colour automatically.

## Priority 2: panel text and layout

### D7 - Panel C x-label

```julia
# static_plotting.jl  (_asset_market_axis)
xlabel = "Quantity of assets traded",
```

### D8 - Panel D title

```julia
# static_plotting.jl  (_balance_axis)
title = rich("($panel_label) ", "Balance Sheet Analysis"; font = :bold),
```

### D4 - reference curve label strings

Rename the module's reference curve labels so they equal the notebook strings
(and so the driver's position dictionaries can key on them):

```julia
# static_plotting.jl  (plot_ad_as, reference block)
x_curve!(builder, "AD (base)", :ADc, :P, reference_solution,
         color = REFERENCE_COLOR, linewidth = 2.5)
x_curve!(builder, "AD (lower i0)", :ADc, :P, lowered_reference_solution,
         color = REFERENCE_COLOR, linewidth = 3.0, linestyle = :dash)

# static_plotting.jl  (plot_asset_market, reference block)
x_curve!(builder, "Asset Demand (base)", :AMD, :AP, reference_solution,
         color = REFERENCE_COLOR, linewidth = 2.5)
x_curve!(builder, "AMD (base, lower i0)", :AMD, :AP, lowered_reference_solution,
         color = REFERENCE_COLOR, linewidth = 2.5, linestyle = :dash)
```

After this, update the driver's position dictionaries so their keys match:
`"AD (base)"` stays; in `asset_market_label_positions` rename `"Demand (base)"`
to `"Asset Demand (base)"` (notebooks 3-5) and add `"AMD (base, lower i0)"` for
notebook 5. See Priority 3 for the exact placement dictionaries.

### D5 - balance-sheet panel layout

The notebooks build Panel D as a fixed 8-segment bar chart. The generic
`balance_sheet_plot_data` / `plot_balance_sheets` routine does not reproduce it.
Replace the body of `plot_balance_sheets` with the notebook's construction,
reading `dM`, `dL`, `dR` (and `SD` if present) from `sol.variables`:

```julia
function plot_balance_sheets(sol::Static.Solution, ax::Makie.Axis)
    dM = sol.variables[:dM]
    dL = sol.variables[:dL]
    dR = sol.variables[:dR]

    inner_gap = 1.2
    group_gap = 1.6
    start_x   = 1.1
    positions = [
        start_x,
        start_x + inner_gap,
        start_x + inner_gap + group_gap,
        start_x + inner_gap + group_gap,
        start_x + inner_gap + group_gap + inner_gap,
        start_x + inner_gap + group_gap + inner_gap,
        start_x + 2 * inner_gap + 2 * group_gap,
        start_x + 2 * inner_gap + 2 * group_gap + inner_gap,
    ]
    bar_vals = [dM, dL, dL, dR, dM, dR, dR, dR]
    bar_clrs = [IS_COLOR, IR_COLOR, IS_COLOR, IS_COLOR,
                IR_COLOR, IR_COLOR, IS_COLOR, IR_COLOR]
    bar_stck = Int[1, 2, 3, 3, 4, 4, 5, 6]
    bar_lbls = [
        @sprintf("D: %.1f", dM),
        @sprintf("L: %.1f", dL),
        @sprintf("L: %.1f", dL),
        @sprintf("R: %.1f", dR),
        @sprintf("D: %.1f", dM),
        @sprintf("CB: %.1f", dR),
        @sprintf("CB: %.1f", dR),
        @sprintf("R: %.1f", dR),
    ]

    barplot!(ax, positions, bar_vals;
             stack = bar_stck, width = 1.2, color = bar_clrs,
             strokecolor = (:black, 0.65), strokewidth = 1.5,
             bar_labels = bar_lbls,
             label_position = :center, label_color = :black, label_size = 14)

    hlines!(ax, [0.0]; color = (:black, 0.55), linewidth = 1.5)
    vlines!(ax, [3.1, 5.9]; ymin = 0.0, ymax = 0.75,
           color = (:black, 0.35), linewidth = 1.0, linestyle = :dash)

    risk = get(sol.variables, :SD, 0.0) / dL
    annotation = join([
        @sprintf("Total Debt / GDP: %.2f", dL / sol.variables[:Y]),
        @sprintf("Speculative Debt / Total Debt: %.2f", risk),
    ], '\n')
    text!(ax, 0.97, 0.97; text = annotation, space = :relative,
          align = (:right, :top), fontsize = FONT_SIZE - 2, color = (:black, 0.75))
    text!(ax, [1.7, 4.5, 7.3], fill(5.2, 3);
          text = ["Private Sector", "Banks", "Central Bank"],
          align = (:center, :bottom), font = :bold, fontsize = FONT_SIZE,
          color = :black)

    xs = [start_x, start_x + inner_gap,
          start_x + inner_gap + group_gap,
          start_x + inner_gap + group_gap + inner_gap,
          start_x + 2 * inner_gap + 2 * group_gap,
          start_x + 2 * inner_gap + 2 * group_gap + inner_gap]
    ax.xticks = (xs, ["Assets", "Liabilities", "Assets",
                      "Liabilities", "Assets", "Liabilities"])
    xlims!(ax, 0.3, 8.7)
    ylims!(ax, 0.0, 8.0)
    return ax
end
```

`balance_sheet_plot_data` and its helpers (`reserve_ratio`, `total_loans`,
`risk_indicator`, `balance_sheet_segment_colors`, `balance_sheet_actor_name`,
the `abbreviation` closure) become unused and can be deleted or kept for other
panels; `total_loans` and `risk_indicator` are folded into the snippet above.

## Priority 3: label-engine refactor (required for exact label placement)

The notebooks place labels with mixed coordinate spaces (`space = :data` for the
IS/IR panel, `space = :relative` elsewhere), per-label `align`/`fontsize`, and a
boxed `textlabel!` for one reference label. The current engine fixes
`space = :relative` and only overrides position. To reproduce exactly, extend
`LabelSpec` to carry its own coordinate space, text, and box flag, and let the
driver supply full `LabelSpec` values.

```julia
# static_plotting.jl
struct LabelSpec
    position::Point2f
    text::Union{Nothing, String}
    attributes::A
end

function LabelSpec(position; text = nothing, attributes...)
    return LabelSpec(Point2f(position...), text, (; attributes...))
end

function reposition_labels(labels, overrides)
    return Dict(label => get(overrides, label, spec)
                for (label, spec) in labels)
end

function plot_curve_label!(ax, curve, labels)
    spec = get(labels, curve.label, nothing)
    isnothing(spec) && return nothing
    base = (space = :relative,
            color = get(curve.attributes, :color, :black),
            fontsize = LEGEND_LABEL_SIZE)
    attrs = merge(base, spec.attributes)
    txt = something(spec.text, curve.label)
    if get(spec.attributes, :box, false)
        textlabel!(ax, spec.position...; text = txt, attrs...,
                   background_color = (:white, 0.8),
                   strokecolor = (:white, 0.8), padding = 8)
    else
        text!(ax, spec.position...; text = txt, attrs...)
    end
    return nothing
end
```

The driver then passes `LabelSpec` values instead of bare `(x, y)` tuples. For
example, the IS/IR block for notebook (2) becomes:

```julia
# produce_static_plots.jl
is_ir = Dict(
    "IS"            => LabelSpec((6.6, 0.14); space = :data,
                                 color = IR_COLOR, align = (:right, :top),
                                 fontsize = LEGEND_SIZE),
    "IR"            => LabelSpec((9.5, 0.139); space = :data,
                                 color = IS_COLOR, align = (:center, :top),
                                 fontsize = LEGEND_SIZE),
    "IR (lower i0)" => LabelSpec((9.3, 0.11); space = :data,
                                 color = IS_COLOR, align = (:center, :top),
                                 fontsize = LEGEND_SIZE),
)
```

and the boxed reference label in notebooks 3-5 is expressed as:

```julia
"AD (lower i0)" => LabelSpec((0.35, 0.45); space = :relative,
                             color = REFERENCE_COLOR, align = (:left, :top),
                             fontsize = LEGEND_SIZE, box = true),
```

Because `reposition_labels` now replaces the whole spec, the default
`STANDARD_IS_IR_LABELS` / `STANDARD_AD_AS_LABELS` /
`STANDARD_ASSET_MARKET_LABELS` dictionaries become the *fallback* for any label
the driver does not override.

# Verification approach

Once the Julia environment is instantiated in this container, the cleanest
verification is to render every notebook figure and every automation figure to
PNG at identical size and diff them pixel-by-pixel (or at least visually).
Concretely:

1. Run each notebook's export cell to `plots/<stem>.png` (the notebooks already
   write there).
2. Run `produce_static_plots.jl` to the same `plots/` directory.
3. Compare `baseline_mathematica_style.png` vs `baseline_equilibrium_panel.png`,
   `pqc_equilibrium_panel.png`, `pqcr_equilibrium_panel.png`,
   `firmsration_equilibrium_panel.png`.

The equilibrium-value dumps at the end of each notebook and at the end of the
driver already let you confirm the *numbers* match before checking pixels. I
have confirmed by reading that the solved equilibria and curve sweeps are
identical; the remaining differences are purely visual (D1-D13 above).

# Decisions needed from you

- Do you want the IS/IR colours kept consistent with the rest of the module
  (IS purple / IR orange) instead of matching the notebooks (IS orange / IR
  purple)? The notebooks are internally inconsistent here (AD and asset demand
  are purple, but IS is orange), so "match the notebook" means IS becomes orange.
- Should the counterfactual stay faded (`alpha = 0.38`) as a deliberate style
  choice, or match the notebooks (full opacity)?
- Should I implement Priority 1-3 now and verify against the notebooks by
  regenerating the PNGs, or would you prefer to review the plan first?
- The `percentage_ticks()` / `LinearTicks(4)` override (D9) and bold axis titles
  (D10) are module additions absent from the notebooks; keep or drop?
