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
                                html_th(var_name, style = th_style),
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
            "flex" => 2,
            "gap" => "16px",
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
    layout = Dict(
        "title" => Dict(
            "text" => "IS – IR Curves",
            "font" => Dict(
                "size" => 18,
                "color" => "#2c3e50",
                "family" => "'Segoe UI', Roboto, sans-serif",
            ),
        ),
        "xaxis" => Dict(
            "title" => Dict("text" => "Interest rate (r)"),
            "gridcolor" => "#e9ecef",
            "zeroline" => false,
        ),
        "yaxis" => Dict(
            "title" => Dict("text" => "Output (Y)"),
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
                "x" => r_eq,
                "y" => y_eq,
                "xref" => "x",
                "yref" => "y",
                "text" => "r* = $(round(r_eq; digits = 4)), Y* = $(round(y_eq; digits = 2))",
                "showarrow" => true,
                "arrowhead" => 2,
                "ax" => 40,
                "ay" => -30,
                "font" => Dict("size" => 12, "color" => "#2c3e50"),
            ),
        ],
    )

    return html_div(
        style = Dict(
            "border" => "1px solid #dee2e6",
            "borderRadius" => "12px",
            "background" => "#fff",
            "padding" => "16px",
            "boxShadow" => "0 2px 12px rgba(0,0,0,0.06)",
            "marginTop" => "24px",
        ),
    ) do
        dcc_graph(
            id = "is-ir-curve-plot",
            figure = Dict(
                "data" => [is_trace, ir_trace, eq_trace],
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

function ad_as_curve_component(solution::Static.Solution)
    # Get the equilibrium values
    AP_eq = solution.variables[:AP]
    AS_eq = solution.variables[:AS]

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
        x = [AS_eq],
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
    layout = Dict(
        "title" => Dict(
            "text" => "AmS – AmD Curves",
            "font" => Dict(
                "size" => 18,
                "color" => "#2c3e50",
                "family" => "'Segoe UI', Roboto, sans-serif",
            ),
        ),
        "xaxis" => Dict(
            "title" => Dict("text" => "Quantity"),
            "gridcolor" => "#e9ecef",
            "zeroline" => false,
        ),
        "yaxis" => Dict(
            "title" => Dict("text" => "Asset price (AP"),
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
                "x" => AS_eq,
                "y" => AP_eq,
                "xref" => "x",
                "yref" => "y",
                "text" => "",
                "showarrow" => true,
                "arrowhead" => 2,
                "ax" => 40,
                "ay" => -30,
                "font" => Dict("size" => 12, "color" => "#2c3e50"),
            ),
        ],
    )

    return html_div(
        style = Dict(
            "border" => "1px solid #dee2e6",
            "borderRadius" => "12px",
            "background" => "#fff",
            "padding" => "16px",
            "boxShadow" => "0 2px 12px rgba(0,0,0,0.06)",
            "marginTop" => "24px",
        ),
    ) do
        dcc_graph(
            id = "is-ir-curve-plot",
            figure = Dict(
                "data" => [ad_trace, as_trace, eq_trace],
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
                curve_component(solution),
                ad_as_curve_component(solution)
        end
    end
end
