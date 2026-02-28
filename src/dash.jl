###############################################################################
# Dash.jl "Model Panel" template
# - Select a model from a list
# - Dynamically render text inputs for that model's parameters
# - Re-solve automatically whenever a parameter changes
# - Display solution + a plot (via Plotly)
###############################################################################

using Dash
using PKAssetPrices

const MODEL_OPTIONS = Dict{String,Static.Parametrization}(
    "Q"  => Static.AssetPKQ,
    "PQ" => Static.AssetPKPQ,
)

# ------------------------------- Dash layout --------------------------------
app = dash(
    suppress_callback_exceptions = true,
)

app.layout = html_div(
    style = Dict(
        "maxWidth"    => "1900px",
        "margin"      => "auto",
        "padding"     => "24px",
        "background"  => "#f0f2f5",
        "minHeight"   => "100vh",
    )
) do
    html_h1("Model Panel",
        style = Dict(
            "color"        => "#2c3e50",
            "fontWeight"   => "700",
            "marginBottom" => "24px",
            "borderBottom" => "3px solid #4a90d9",
            "paddingBottom"=> "12px",
        ),
    ),
    html_div(
        style = Dict(
            "background"   => "#fff",
            "borderRadius" => "12px",
            "padding"      => "24px",
            "boxShadow"    => "0 2px 12px rgba(0,0,0,0.08)",
            "marginBottom" => "24px",
        )
    ) do
        # ── Model selector ──
        html_label("Model",
            style = Dict(
                "fontWeight"   => "600",
                "fontSize"     => "13px",
                "color"        => "#6c757d",
                "textTransform"=> "uppercase",
                "letterSpacing"=> "0.8px",
                "marginBottom" => "6px",
                "display"      => "block",
            ),
        ),
        dcc_dropdown(
            id    = "model-dropdown",
            options = [(label = k, value = k) for k in keys(MODEL_OPTIONS)],
            value = "Q",
            style = Dict(
                "marginBottom" => "20px",
            ),
        ),

        # ── Dynamic parameter inputs ──
        html_div(id = "param-container")
    end,
    html_hr(style = Dict("border" => "none", "borderTop" => "1px solid #dee2e6", "margin" => "24px 0")),
    # ── Loading wrapper around the solution output ──
    dcc_loading(
        id = "solution-loading",
        type = "circle",
        children = html_div(id = "solution-output"),
    )
end

# ── Callback 1: rebuild parameter inputs when the model changes ─────────────
callback!(
    app,
    Output("param-container", "children"),
    Input("model-dropdown", "value"),
) do model_name
    model = MODEL_OPTIONS[model_name]
    params  = model.params

    param_inputs = html_div(
        style = Dict(
            "display"             => "grid",
            "gridTemplateColumns" => "repeat(auto-fill, minmax(200px, 1fr))",
            "gap"                 => "16px",
            "padding"             => "8px 0 20px 0",
        ),
    ) do
        [
            html_div(
                style = Dict(
                    "display"      => "flex",
                    "flexDirection"=> "column",
                    "gap"          => "4px",
                ),
            ) do
                html_label(
                    "$pname",
                    style = Dict(
                        "fontWeight"   => "600",
                        "fontSize"     => "12px",
                        "color"        => "#6c757d",
                        "textTransform"=> "uppercase",
                        "letterSpacing"=> "0.6px",
                    ),
                ),
                dcc_input(
                    id       = (type = "param-input", index = pname),
                    type     = "number",
                    value    = pval,
                    debounce = true,
                    style    = Dict(
                        "width"        => "100%",
                        "padding"      => "10px 12px",
                        "borderRadius" => "8px",
                        "border"       => "1px solid #dee2e6",
                        "fontSize"     => "14px",
                        "background"   => "#f8f9fa",
                        "transition"   => "border-color 0.2s ease, box-shadow 0.2s ease",
                        "outline"      => "none",
                        "boxSizing"    => "border-box",
                    ),
                )
            end
            for (pname, pval) in params
        ]
    end

    hidden_store = dcc_store(
        id = "param-names-store",
        data = [pname for (pname, _) in params],
    )

    return vcat(param_inputs, [hidden_store])
end

const table_style = Dict(
        "borderCollapse" => "collapse",
        "fontSize"       => "14px",
        "border"         => "1px solid #dee2e6",
        "borderRadius"   => "8px",
        "overflow"       => "hidden",
    )

const    td_name_style = Dict(
        "padding"      => "10px 16px",
        "fontWeight"   => "600",
        "textAlign"    => "left",
        "background"   => "#f8f9fa",
        "borderBottom" => "1px solid #dee2e6",
        "borderRight"  => "1px solid #dee2e6",
    )

    const td_value_style = Dict(
        "padding"      => "10px 16px",
        "textAlign"    => "right",
        "background"   => "#f8f9fa",
        "borderBottom" => "1px solid #dee2e6",
        "borderRight"  => "1px solid #dee2e6",
    )

    const td_total_name_style = Dict(
        "padding"      => "10px 16px",
        "fontWeight"   => "700",
        "textAlign"    => "left",
        "background"   => "#e9ecef",
        "borderTop"    => "2px solid #4a90d9",
        "borderRight"  => "1px solid #dee2e6",
    )

    const td_total_value_style = Dict(
        "padding"      => "10px 16px",
        "fontWeight"   => "700",
        "textAlign"    => "right",
        "background"   => "#e9ecef",
        "borderTop"    => "2px solid #4a90d9",
        "borderRight"  => "1px solid #dee2e6",
    )


const th_style = Dict(
        "background"     => "#ffff",
        "color"          => "#4a90d9",
        "fontWeight"     => "600",
        "padding"        => "10px 16px",
        "textAlign"      => "right",
        "whiteSpace"     => "nowrap",
        "borderBottom"   => "1px solid rgba(255,255,255,0.2)",
        "letterSpacing"  => "0.3px",
    )

const td_style = Dict(
        "padding"      => "10px 16px",
        "textAlign"    => "left",
        "background"   => "#f8f9fa",
        "borderBottom" => "1px solid #dee2e6",
        "borderLeft"   => "2px solid #dee2e6",
    )
const    sector_title_style = Dict(
        "margin"       => "0 0 12px 0",
        "fontSize"     => "16px",
        "fontWeight"   => "700",
        "color"        => "#4a90d9",
    )

const    card_style = Dict(
        "border"       => "1px solid #dee2e6",
        "borderRadius" => "8px",
        "padding"      => "16px",
        "background"   => "#fff",
        "minWidth"     => "340px",
        "flex"         => "1",
    )

function variable_component(solution::Static.Solution)
    var_names = solution.model.model.variables


    return html_div(
        style = Dict(
            "overflowX"    => "auto",
            "marginBottom" => "24px",
        ),
    ) do
        html_table(style = table_style) do
            html_tbody([
                html_tr([
                    html_th(var_name, style = th_style),
                    html_td(
                        string(round(solution.variables[var_name]; digits = 6)),
                        style = td_style,
                    ),
                ])
                for var_name in var_names
            ])
        end
    end
end

function table_from_balance_sheet(sheet :: Static.BalanceSheetFilled)
        html_div(style = card_style) do
            html_h3(Static.title_from_snake(sheet.sector_name), style = sector_title_style),
            html_table(style = table_style) do
                html_thead(
                    html_tr([
                        html_th("Assets",      style = th_style),
                        html_th("Value",       style = th_style),
                        html_th("Liabilities", style = th_style),
                        html_th("Value",       style = th_style),
                    ])
                ),
                html_tbody([
                    html_tr([
                        html_td(Static.title_from_snake(asset[1]),                    style = td_name_style),
                        html_td(string(round(asset[2]; digits = 2)),           style = td_value_style),
                        html_td(Static.title_from_snake(liability[1]),                style = td_name_style),
                        html_td(string(round(liability[2]; digits = 2)),       style = td_value_style),
                    ])
                    for (asset, liability) in zip(sheet.assets, sheet.liabilities)
                ]),
                html_tfoot(
                    html_tr([
                        html_td("Total",                                       style = td_total_name_style),
                        html_td(string(round(Static.assets(sheet); digits = 2)),      style = td_total_value_style),
                        html_td("Total",                                       style = td_total_name_style),
                        html_td(string(round(Static.liabilities(sheet); digits = 2)), style = td_total_value_style),
                    ])
                )
            end
        end

end


function balance_sheet_component(solution::Static.Solution)

    isempty(solution.sheets) && return html_div()
    cards = table_from_balance_sheet.(solution.sheets)
        
     return html_div(
        style = Dict(
            "display"    => "flex",
            "flexWrap"   => "wrap",
            "gap"        => "16px",
            "alignItems" => "flex-start",
        ),
    ) do
        cards
    end
end


function curve_component(solution::Static.Solution)
    # Get the equilibrium values
    r_eq = solution.variables[:r]
    y_eq = solution.variables[:Y]

    # Build a range of r values around the equilibrium for IS
    r_min = r_eq * 0.2
    r_max = r_eq * 3.0
    r_range = range(r_min, r_max; length = 200)

    # Build a range of Y values around the equilibrium for IR
    y_min = y_eq * 0.2
    y_max = y_eq * 3.0
    y_range = range(y_min, y_max; length = 200)

    # IS curve: r → Y  (plot as x=r, y=IS(r))
    is_values = Float64[]
    for r in r_range
        vars = copy(solution.variables)
        vars[:r] = r
        curves = Static.eval_curve(solution.model, vars)
        push!(is_values, curves.IS)
    end

    # IR curve: Y → r  (plot as x=IR(Y), y=Y so both axes match)
    ir_r_values = Float64[]
    for y in y_range
        vars = copy(solution.variables)
        vars[:Y] = y
        curves = Static.eval_curve(solution.model, vars)
        push!(ir_r_values, curves.IR)
    end

    # ── Plotly traces ──
    is_trace = (
        x    = collect(r_range),
        y    = is_values,
        type = "scatter",
        mode = "lines",
        name = "IS",
        line = Dict(
            "color" => "#4a90d9",
            "width" => 3,
        ),
    )

    # IR: x = IR(Y) (the r values), y = Y
    ir_trace = (
        x    = ir_r_values,
        y    = collect(y_range),
        type = "scatter",
        mode = "lines",
        name = "IR",
        line = Dict(
            "color" => "#e74c3c",
            "width" => 3,
        ),
    )

    eq_trace = (
        x    = [r_eq],
        y    = [y_eq],
        type = "scatter",
        mode = "markers",
        name = "Equilibrium",
        marker = Dict(
            "color"  => "#2c3e50",
            "size"   => 12,
            "symbol" => "circle",
            "line"   => Dict(
                "color" => "#fff",
                "width" => 2,
            ),
        ),
        showlegend = true,
    )

    # ── Layout ──
    layout = Dict(
        "title" => Dict(
            "text" => "IS – IR Curves",
            "font" => Dict(
                "size"   => 18,
                "color"  => "#2c3e50",
                "family" => "'Segoe UI', Roboto, sans-serif",
            ),
        ),
        "xaxis" => Dict(
            "title"     => Dict("text" => "Interest rate (r)"),
            "gridcolor" => "#e9ecef",
            "zeroline"  => false,
        ),
        "yaxis" => Dict(
            "title"     => Dict("text" => "Output (Y)"),
            "gridcolor" => "#e9ecef",
            "zeroline"  => false,
        ),
        "legend" => Dict(
            "orientation" => "h",
            "yanchor"     => "bottom",
            "y"           => 1.02,
            "xanchor"     => "right",
            "x"           => 1,
            "font"        => Dict("size" => 13),
        ),
        "plot_bgcolor"  => "#fafbfc",
        "paper_bgcolor" => "#fff",
        "margin"        => Dict("l" => 60, "r" => 24, "t" => 60, "b" => 50),
        "hovermode"     => "x unified",
        "annotations"   => [
            Dict(
                "x"         => r_eq,
                "y"         => y_eq,
                "xref"      => "x",
                "yref"      => "y",
                "text"      => "r* = $(round(r_eq; digits=4)), Y* = $(round(y_eq; digits=2))",
                "showarrow" => true,
                "arrowhead" => 2,
                "ax"        => 40,
                "ay"        => -30,
                "font"      => Dict("size" => 12, "color" => "#2c3e50"),
            ),
        ],
    )

    return html_div(
        style = Dict(
            "border"       => "1px solid #dee2e6",
            "borderRadius" => "12px",
            "background"   => "#fff",
            "padding"      => "16px",
            "boxShadow"    => "0 2px 12px rgba(0,0,0,0.06)",
            "marginTop"    => "24px",
        ),
    ) do
        dcc_graph(
            id     = "is-ir-curve-plot",
            figure = Dict(
                "data"   => [is_trace, ir_trace, eq_trace],
                "layout" => layout,
            ),
            config = Dict(
                "displayModeBar" => true,
                "displaylogo"    => false,
                "modeBarButtonsToRemove" => ["lasso2d", "select2d"],
            ),
            style = Dict(
                "width"  => "100%",
                "height" => "480px",
            ),
        )
    end
end


function solution_component(solution::Static.Solution)
    return html_div() do
        html_h3("Solution"),
        html_div(
            style = Dict(
                "display"    => "flex",
                "flexWrap"   => "wrap",
                "gap"        => "16px",
                "alignItems" => "flex-start",
            ),
        ) do
            variable_component(solution),
            balance_sheet_component(solution)
        end,
        curve_component(solution)
    end
end

# ── Callback 2: solve whenever params change OR model changes ────────────────
callback!(
    app,
    Output("solution-output", "children"),
    Input("model-dropdown", "value"),
    Input((type = "param-input", index = ALL), "value"),
    State("param-names-store", "data"),
) do model_name, param_values, param_names
    # On initial load or when model just changed, param_names may be nothing
    # or param_values may be empty — solve with defaults in that case
    p = MODEL_OPTIONS[model_name]

    if !isnothing(param_names) && !isempty(param_values) && length(param_names) == length(param_values)
        # Check that all values are valid numbers (not nothing/missing)
        if all(v -> v isa Number, param_values)
            new_params = Dict(Symbol(k) => Float64(v) for (k, v) in zip(param_names, param_values))
            p = Static.Parametrization(p.model, new_params, p.u0)
        end
    end

    sol = solve_model(p)
    solution_component(sol)
end

run_server(app, "0.0.0.0", 8050; debug = true)
