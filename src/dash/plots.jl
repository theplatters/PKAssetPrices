function get_layout(;
    title,
    xaxis_title,
    yaxis_title,
    x_annotation = 0.0,
    y_annotation = 0.0,
    annotation_text = "",
    show_annotation = true,
)
    axis(title) = Dict(
        "title" => title,
        "showline" => true,
        "linecolor" => COLORS.ink,
        "linewidth" => 1,
        "mirror" => false,
        "gridcolor" => COLORS.grid,
        "gridwidth" => 1,
        "zeroline" => false,
        "ticks" => "outside",
        "tickcolor" => COLORS.ink,
        "tickfont" => Dict("size" => 11, "color" => COLORS.muted),
        "automargin" => true,
    )

    annotations = show_annotation ? [
        Dict(
            "x" => x_annotation,
            "y" => y_annotation,
            "xref" => "x",
            "yref" => "y",
            "text" => annotation_text,
            "showarrow" => true,
            "arrowhead" => 0,
            "arrowcolor" => COLORS.ink,
            "arrowwidth" => 1,
            "ax" => 48,
            "ay" => -38,
            "bgcolor" => "rgba(255, 254, 250, 0.94)",
            "bordercolor" => COLORS.grid,
            "borderpad" => 6,
            "font" => Dict("size" => 11, "color" => COLORS.ink),
        ),
    ] : Any[]

    return Dict(
        "title" => Dict(
            "text" => title,
            "x" => 0,
            "xanchor" => "left",
            "font" => Dict("size" => 16, "color" => COLORS.ink, "family" => PLOT_FONT),
        ),
        "font" => Dict("family" => PLOT_FONT, "color" => COLORS.ink),
        "xaxis" => axis(xaxis_title),
        "yaxis" => axis(yaxis_title),
        "legend" => Dict(
            "orientation" => "h",
            "yanchor" => "bottom",
            "y" => 1.02,
            "xanchor" => "right",
            "x" => 1,
            "font" => Dict("size" => 11),
        ),
        "plot_bgcolor" => COLORS.paper,
        "paper_bgcolor" => COLORS.paper,
        "margin" => Dict("l" => 58, "r" => 20, "t" => 66, "b" => 54),
        "hovermode" => "closest",
        "hoverlabel" => Dict(
            "bgcolor" => COLORS.ink,
            "font" => Dict("family" => PLOT_FONT, "size" => 11, "color" => "#ffffff"),
            "bordercolor" => COLORS.ink,
        ),
        "annotations" => annotations,
    )
end

function curve_component(data, layout)
    return html_div(className = "chart-card") do
        dcc_graph(
            figure = Dict("data" => data, "layout" => layout),
            config = Dict(
                "displayModeBar" => true,
                "displaylogo" => false,
                "responsive" => true,
                "modeBarButtonsToRemove" => ["lasso2d", "select2d", "autoScale2d"],
                "toImageButtonOptions" => Dict("format" => "svg", "filename" => "pk-model-curve"),
            ),
            className = "workbook-graph",
        )
    end
end

function is_ir_component(solution::Static.Solution)
    output_range = range(0.0, 15.0; length = 200)
    rate_range = range(0.0, 0.20; length = 200)

    is_values = map(rate_range) do rate
        variables = copy(solution.variables)
        variables[:r] = rate
        return Static.eval_curve(solution.model, variables).IS
    end
    ir_values = map(output_range) do output
        variables = copy(solution.variables)
        variables[:Y] = output
        return Static.eval_curve(solution.model, variables).IR
    end

    traces = Any[
        (
            x = is_values,
            y = collect(rate_range),
            type = "scatter",
            mode = "lines",
            name = "IS",
            hovertemplate = "Y %{x:.3f}<br>r %{y:.4f}<extra>IS</extra>",
            line = Dict("color" => COLORS.primary, "width" => 2.5),
        ),
        (
            x = collect(output_range),
            y = ir_values,
            type = "scatter",
            mode = "lines",
            name = "IR",
            hovertemplate = "Y %{x:.3f}<br>r %{y:.4f}<extra>IR</extra>",
            line = Dict("color" => COLORS.accent, "width" => 2.5),
        ),
    ]

    if all(haskey(solution.variables, key) for key in (:Y, :r))
        push!(traces, (
            x = [solution.variables[:Y]],
            y = [solution.variables[:r]],
            type = "scatter",
            mode = "markers",
            name = "Equilibrium",
            hovertemplate = "Y* %{x:.3f}<br>r* %{y:.4f}<extra></extra>",
            marker = Dict(
                "color" => COLORS.ink,
                "size" => 9,
                "line" => Dict("color" => COLORS.paper, "width" => 2),
            ),
        ))
    end

    layout = get_layout(
        title = "Goods and interest-rate equilibrium",
        xaxis_title = Dict("text" => "Output, Y"),
        yaxis_title = Dict("text" => "Interest rate, r"),
        show_annotation = false,
    )
    layout["xaxis"]["range"] = [0.0, 15.0]
    layout["yaxis"]["range"] = [0.0, 0.20]
    return curve_component(traces, layout)
end

function ad_as_curve_component(solution::Static.Solution)
    asset_price = solution.variables[:AP]
    equilibrium_quantity = Static.eval_curve(solution).AMD
    price_range = range(asset_price * 0.2, asset_price * 3.0; length = 200)

    demand_values = Float64[]
    supply_values = Float64[]
    for price in price_range
        variables = copy(solution.variables)
        variables[:AP] = price
        curves = Static.eval_curve(solution.model, variables)
        push!(demand_values, curves.AMD)
        push!(supply_values, curves.AMS)
    end

    traces = [
        (
            x = demand_values,
            y = collect(price_range),
            type = "scatter",
            mode = "lines",
            name = "AmD",
            hovertemplate = "Q %{x:.3f}<br>AP %{y:.3f}<extra>AmD</extra>",
            line = Dict("color" => COLORS.primary, "width" => 2.5),
        ),
        (
            x = supply_values,
            y = collect(price_range),
            type = "scatter",
            mode = "lines",
            name = "AmS",
            hovertemplate = "Q %{x:.3f}<br>AP %{y:.3f}<extra>AmS</extra>",
            line = Dict("color" => COLORS.teal, "width" => 2.5),
        ),
        (
            x = [equilibrium_quantity],
            y = [asset_price],
            type = "scatter",
            mode = "markers",
            name = "Equilibrium",
            hovertemplate = "Q* %{x:.3f}<br>AP* %{y:.3f}<extra></extra>",
            marker = Dict(
                "color" => COLORS.ink,
                "size" => 9,
                "line" => Dict("color" => COLORS.paper, "width" => 2),
            ),
        ),
    ]

    layout = get_layout(
        title = "Asset-market equilibrium",
        xaxis_title = Dict("text" => "Asset quantity, Q"),
        yaxis_title = Dict("text" => "Asset price, AP"),
        x_annotation = equilibrium_quantity,
        y_annotation = asset_price,
        annotation_text = "Q* = $(format_value(equilibrium_quantity; digits = 4))<br>" *
            "AP* = $(format_value(asset_price; digits = 2))",
    )
    return curve_component(traces, layout)
end
