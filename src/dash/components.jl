function variable_component(solution::Static.Solution)
    var_names = solution.model.model.variables


    return html_div(
        style = Dict(
            "overflowX" => "auto",
            "marginBottom" => "24px",
        ),
    ) do
        html_table(style = table_style) do
            html_tbody(
                [
                    html_tr(
                            [
                                html_th(var_name, style = th_style, title = solution.model.model.variable_descriptions[var_name]),
                                html_td(
                                    string(round(solution.variables[var_name]; digits = 6)),
                                    style = td_style,
                                ),
                            ]
                        )
                        for var_name in var_names
                ]
            )
        end
    end
end

function table_from_balance_sheet(sheet::Static.BalanceSheetFilled)
    return html_div(style = card_style) do
        html_h3(Static.title_from_snake(sheet.sector_name), style = sector_title_style),
            html_table(style = table_style) do
                html_thead(
                    html_tr(
                        [
                            html_th("Assets", style = th_style),
                            html_th("Value", style = th_style),
                            html_th("Liabilities", style = th_style),
                            html_th("Value", style = th_style),
                        ]
                    )
                ),
                html_tbody(
                    [
                        html_tr(
                            [
                                html_td(Static.title_from_snake(asset[1]), style = td_name_style),
                                html_td(string(round(asset[2]; digits = 2)), style = td_value_style),
                                html_td(Static.title_from_snake(liability[1]), style = td_name_style),
                                html_td(string(round(liability[2]; digits = 2)), style = td_value_style),
                            ]
                        )
                        for (asset, liability) in zip(sheet.assets, sheet.liabilities)
                    ]
                ),
                html_tfoot(
                    html_tr(
                        [
                            html_td("Total", style = td_total_name_style),
                            html_td(string(round(Static.assets(sheet); digits = 2)), style = td_total_value_style),
                            html_td("Total", style = td_total_name_style),
                            html_td(string(round(Static.liabilities(sheet); digits = 2)), style = td_total_value_style),
                        ]
                    )
                )
        end
    end

end

function balance_sheet_component(solution::Static.Solution)

    isempty(solution.sheets) && return html_div()
    cards = table_from_balance_sheet.(solution.sheets)

    return html_div(
        style = Dict(
            "display" => "flex",
            "flexWrap" => "wrap",
            "flex-direction" => "column",
            "flex" => 2,
            "gap" => "16px",
            "alignItems" => "flex-start",
        ),
    ) do
        cards
    end
end

function curve_component(data, layout)
    return html_div(
        style = Dict(
            "border" => "1px solid #dee2e6",
            "borderRadius" => "12px",
            "background" => "#fff",
            "padding" => "16px",
            "boxShadow" => "0 2px 12px rgba(0,0,0,0.06)",
        ),
    ) do
        dcc_graph(
            id = "is-ir-curve-plot",
            figure = Dict(
                "data" => data,
                "layout" => layout,
            ),
            config = Dict(
                "displayModeBar" => true,
                "displaylogo" => false,
                "modeBarButtonsToRemove" => ["lasso2d", "select2d"],
            ),
            style = Dict(
                "width" => "100%",
                "height" => "480px",
            ),
        )
    end
end

function get_layout(; title, xaxis_title, yaxis_title, x_annotation, y_annotation, annotatation_text)
    return Dict(
        "title" => Dict(
            "text" => title,
            "font" => Dict(
                "size" => 18,
                "color" => "#2c3e50",
                "family" => "'Segoe UI', Roboto, sans-serif",
            ),
        ),
        "xaxis" => Dict(
            "title" => xaxis_title,
            "gridcolor" => "#e9ecef",
            "zeroline" => false,
        ),
        "yaxis" => Dict(
            "title" => yaxis_title,
            "gridcolor" => "#e9ecef",
            "zeroline" => false,
        ),
        "legend" => Dict(
            "orientation" => "h",
            "yanchor" => "bottom",
            "y" => 1.02,
            "xanchor" => "right",
            "x" => 1,
            "font" => Dict("size" => 13),
        ),
        "plot_bgcolor" => "#fafbfc",
        "paper_bgcolor" => "#fff",
        "margin" => Dict("l" => 60, "r" => 24, "t" => 60, "b" => 50),
        "hovermode" => "x unified",
        "annotations" => [
            Dict(
                "x" => x_annotation,
                "y" => y_annotation,
                "xref" => "x",
                "yref" => "y",
                "text" => annotatation_text,
                "showarrow" => true,
                "arrowhead" => 2,
                "ax" => 40,
                "ay" => -30,
                "font" => Dict("size" => 12, "color" => "#2c3e50"),
            ),
        ],
    )
end


function is_ir_component(solution::Static.Solution)
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
        x = collect(r_range),
        y = is_values,
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
        x = ir_r_values,
        y = collect(y_range),
        type = "scatter",
        mode = "lines",
        name = "IR",
        line = Dict(
            "color" => "#e74c3c",
            "width" => 3,
        ),
    )

    eq_trace = (
        x = [r_eq],
        y = [y_eq],
        type = "scatter",
        mode = "markers",
        name = "Equilibrium",
        marker = Dict(
            "color" => "#2c3e50",
            "size" => 12,
            "symbol" => "circle",
            "line" => Dict(
                "color" => "#fff",
                "width" => 2,
            ),
        ),
        showlegend = true,
    )

    # ── Layout ──
    layout = get_layout(
        title = "IS – IR Curves",
        xaxis_title = Dict("text" => "Interest rate (r)"),
        yaxis_title = Dict("text" => "Output (Y)"),
        x_annotation = r_eq,
        y_annotation = y_eq,
        annotatation_text = "r* = $(round(r_eq; digits = 4)),
                        Y* = $(round(y_eq; digits = 2))"
    )


    return curve_component([is_trace, ir_trace, eq_trace], layout)

end

function ad_as_curve_component(solution::Static.Solution)
    # Get the equilibrium values
    AP_eq = solution.variables[:AP]
    AS_eq = solution.variables[:AS]
    AD_eq = solution.variables[:AD]

    # Build a range of r values around the equilibrium for IS
    AP_min = AP_eq * 0.2
    AP_max = AP_eq * 3.0
    AP_range = range(AP_min, AP_max; length = 200)


    # IS curve: r → Y  (plot as x=r, y=IS(r))
    ad_values = Float64[]
    as_values = Float64[]
    for AP in AP_range
        vars = copy(solution.variables)
        vars[:AP] = AP
        curves = Static.eval_curve(solution.model, vars)
        push!(ad_values, curves.AMD)
        push!(as_values, curves.AMS)
    end


    # ── Plotly traces ──
    ad_trace = (
        y = collect(AP_range),
        x = ad_values,
        type = "scatter",
        mode = "lines",
        name = "AmD",
        line = Dict(
            "color" => "#4a90d9",
            "width" => 3,
        ),
    )

    # IR: x = IR(Y) (the r values), y = Y
    as_trace = (
        y = collect(AP_range),
        x = as_values,
        type = "scatter",
        mode = "lines",
        name = "AmS",
        line = Dict(
            "color" => "#e74c3c",
            "width" => 3,
        ),
    )

    eq_trace = (
        x = [AD_eq / AP_eq],
        y = [AP_eq],
        type = "scatter",
        mode = "markers",
        name = "Equilibrium",
        marker = Dict(
            "color" => "#2c3e50",
            "size" => 12,
            "symbol" => "circle",
            "line" => Dict(
                "color" => "#fff",
                "width" => 2,
            ),
        ),
        showlegend = true,
    )

    # ── Layout ──
    layout = get_layout(
        title = "AmS – AmD Curves",
        xaxis_title = Dict("text" => "Quantity"),
        yaxis_title = Dict("text" => "Asset price (AP"),
        x_annotation = AD_eq / AD_eq,
        y_annotation = AP_eq,
        annotatation_text = "Q* = $(round(AS_eq; digits = 4)),
                        AP* = $(round(AP_eq; digits = 2))"
    )


    return curve_component([ad_trace, as_trace, eq_trace], layout)
end


function param_inputs(param_names, params, param_descriptions; id = pname -> (type = "param-input", index = pname))
    return html_div(
        style = Dict(
            "display" => "grid",
            "gridTemplateColumns" => "repeat(auto-fill, minmax(200px, 1fr))",
            "gap" => "16px",
            "padding" => "8px 0 20px 0",
        ),
    ) do
        [
            html_div(
                    title = param_descriptions[Symbol(pname)],
                    style = Dict(
                        "display" => "flex",
                        "flexDirection" => "column",
                        "gap" => "4px",
                    ),
                ) do
                    html_label(
                        "$pname",
                        style = Dict(
                            "fontWeight" => "600",
                            "fontSize" => "12px",
                            "color" => "#6c757d",
                            "textTransform" => "uppercase",
                            "letterSpacing" => "0.6px",
                        ),
                    ),
                    dcc_input(
                        id = id(pname),
                        type = "number",
                        value = params[Symbol(pname)],
                        debounce = true,
                        style = dcc_input_style
                    )
            end
                for pname in param_names
        ]
    end
end

function get_param_input(param_names, params, param_descriptions)
    key = hash(param_names)
    return get!(COMPONENT_CACHE, key) do
        param_inputs(param_names, params, param_descriptions)
    end
end


function solution_component(solution::Static.Solution)
    return html_div() do
        html_h3("Solution"),
            html_div(
                style = Dict(
                    "display" => "flex",
                    "flexWrap" => "wrap",
                    "gap" => "16px",
                    "alignItems" => "flex-start",
                ),
            ) do
                variable_component(solution),
                balance_sheet_component(solution),
                is_ir_component(solution),
                ad_as_curve_component(solution)
        end
    end
end

function model_column(model_options, idx::Int)
    return html_div(
        id = (type = "cmp-col", index = idx),
        style = Dict(
            "background" => "#fff",
            "borderRadius" => "12px",
            "padding" => "20px",
            "boxShadow" => "0 2px 12px rgba(0,0,0,0.08)",
            "minWidth" => "280px",
            "flex" => "1 1 0",
        ),
    ) do
        html_h3(
                "Model $idx",
                style = Dict(
                    "color" => "#4a90d9",
                    "fontWeight" => "600",
                    "marginBottom" => "12px",
                ),
            ),
            html_label(
                "Model",
                style = Dict(
                    "fontWeight" => "600",
                    "fontSize" => "13px",
                    "color" => "#6c757d",
                    "textTransform" => "uppercase",
                    "letterSpacing" => "0.8px",
                    "marginBottom" => "6px",
                    "display" => "block",
                ),
            ),
            dcc_dropdown(
                id = (type = "cmp-model-dropdown", index = idx),
                options = [(label = k, value = k) for k in keys(model_options)],
                value = first(keys(model_options)),
                style = Dict("marginBottom" => "16px"),
            ),
            html_div(id = (type = "cmp-param-container", index = idx)),
            dcc_store(
                id = (type = "cmp-param-names-store", index = idx),
                data = [],
            )
    end
end

function add_model_button()
    return html_div(
        style = Dict(
            "display" => "flex",
            "alignItems" => "center",
            "justifyContent" => "center",
            "minWidth" => "64px",
        ),
    ) do
        html_button(
            "+",
            id = "cmp-add-model-btn",
            n_clicks = 0,
            style = Dict(
                "width" => "48px",
                "height" => "48px",
                "borderRadius" => "50%",
                "border" => "2px dashed #4a90d9",
                "background" => "transparent",
                "color" => "#4a90d9",
                "fontSize" => "24px",
                "fontWeight" => "700",
                "cursor" => "pointer",
                "transition" => "all 0.2s",
            ),
        )
    end
end

function curves_grid(solutions, labels)
    n = length(solutions)

    cards = map(1:n) do i
        sol = solutions[i]
        label = labels[i]

        html_div(
            style = Dict(
                "background" => "#fff",
                "borderRadius" => "12px",
                "padding" => "16px",
                "boxShadow" => "0 2px 8px rgba(0,0,0,0.06)",
            ),
        ) do
            html_h4(
                    label,
                    style = Dict(
                        "color" => "#4a90d9",
                        "fontWeight" => "600",
                        "marginBottom" => "12px",
                        "textAlign" => "center",
                    ),
                ),
                is_ir_component(sol),
                ad_as_curve_component(sol)
        end
    end

    return html_div(
        style = Dict(
            "display" => "grid",
            "gridTemplateColumns" => "repeat($n, 1fr)",
            "gap" => "20px",
        ),
    ) do
        cards
    end
end

# ── Balance-sheet comparison table ───────────────────────────────────

function balance_sheet_comparison_table(solutions, labels)

    return html_div(
        style = Dict("overflowX" => "auto"),
    ) do
        html_div(
            style = Dict(
                "width" => "100%",
                "borderCollapse" => "collapse",
                "fontSize" => "14px",
                "display" => "flex",
            ),
        ) do
            [balance_sheet_component(sol) for sol in solutions]
        end
    end
end

# ── Variable comparison table ────────────────────────────────────────

function variable_comparison_table(solutions, labels)
    # Collect the union of all variable names
    all_vars = unique(vcat([collect(keys(sol.variables)) for sol in solutions]...))
    all_var_descriptions = merge([sol.model.model.variable_descriptions for sol in solutions]...)
    sort!(all_vars)

    header = vcat(
        [html_th("Variable", style = th_style)],
        [html_th(lbl, style = th_style) for lbl in labels],
    )

    rows = map(all_vars) do var
        cells = vcat(
            [html_td(string(var), style = td_style)],
            [
                html_td(
                        haskey(sol.variables, var) ? round(sol.variables[var]; digits = 4) : "—",
                        style = td_style,
                    )
                    for sol in solutions
            ],
        )
        html_tr(cells, title = all_var_descriptions[var])
    end

    return html_div(
        style = Dict("overflowX" => "auto"),
    ) do
        html_table(
            style = Dict(
                "width" => "100%",
                "borderCollapse" => "collapse",
                "fontSize" => "14px",
            ),
        ) do
            html_thead(html_tr(header)),
                html_tbody(rows)
        end
    end
end


"""
Build the full comparison output: variable table, balance-sheet table,
and a grid of IS-LM / AD-AS curve plots.
"""
function comparison_results(solutions, labels)
    return html_div() do
        # ── Section 1: Variable comparison table ──
        html_h2(
                "Variables Comparison",
                style = Dict(
                    "color" => "#2c3e50",
                    "fontWeight" => "600",
                    "marginBottom" => "12px",
                ),
            ),
            variable_comparison_table(solutions, labels),

            html_hr(style = Dict("border" => "none", "borderTop" => "1px solid #dee2e6", "margin" => "24px 0")),

            # ── Section 2: Balance-sheet comparison table ──
            html_h2(
                "Balance Sheets Comparison",
                style = Dict(
                    "color" => "#2c3e50",
                    "fontWeight" => "600",
                    "marginBottom" => "12px",
                ),
            ),
            balance_sheet_comparison_table(solutions, labels),

            html_hr(style = Dict("border" => "none", "borderTop" => "1px solid #dee2e6", "margin" => "24px 0")),

            # ── Section 3: IS-LM & AD-AS curve grid ──
            html_h2(
                "IS-LM & AD-AS Curves",
                style = Dict(
                    "color" => "#2c3e50",
                    "fontWeight" => "600",
                    "marginBottom" => "12px",
                ),
            ),
            curves_grid(solutions, labels)
    end
end
