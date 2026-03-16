model_explore(model_options) = html_div() do
    html_h1(
            "Model Panel",
            style = Dict(
                "color" => "#2c3e50",
                "fontWeight" => "700",
                "marginBottom" => "24px",
                "borderBottom" => "3px solid #4a90d9",
                "paddingBottom" => "12px",
            ),
        ),
        html_div(
            style = Dict(
                "background" => "#fff",
                "borderRadius" => "12px",
                "padding" => "24px",
                "boxShadow" => "0 2px 12px rgba(0,0,0,0.08)",
                "marginBottom" => "24px",
            )
        ) do
            # ── Model selector ──
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
                id = "model-dropdown",
                options = [(label = k, value = k) for k in keys(model_options)],
                value = "PQ",
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

function comparisons(model_options)
    html_div(
        style = Dict("padding" => "24px"),
    ) do
        html_h1(
            "Model Comparison",
            style = Dict(
                "color"        => "#2c3e50",
                "fontWeight"   => "700",
                "marginBottom" => "24px",
                "borderBottom" => "3px solid #4a90d9",
                "paddingBottom"=> "12px",
            ),
        ),

        # ── Store that tracks how many model columns are active ──
        dcc_store(id = "cmp-num-models", data = 2),

        # ── Grid of model columns + "+" button ──
        html_div(
            id = "cmp-columns-container",
            style = Dict(
                "display"  => "flex",
                "gap"      => "20px",
                "overflowX"=> "auto",
                "padding"  => "4px 0 24px 0",
            ),
        ) do
            model_column(model_options, 1),
            model_column(model_options, 2),
            add_model_button()
        end,

        html_hr(style = Dict("border" => "none", "borderTop" => "1px solid #dee2e6", "margin" => "24px 0")),

        # ── Comparison results (tables + graphs) ──
        dcc_loading(
            id = "cmp-loading",
            type = "circle",
            children = html_div(id = "cmp-results-output"),
        )
    end
end


