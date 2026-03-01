function get_app(model_options::Dict{String, Static.Parametrization})
    app = dash(
        suppress_callback_exceptions = true,
    )

    app.layout = html_div() do
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

    return app
end


function register_callbacks!(app, model_options)
    callback!(
        app,
        Output("param-container", "children"),
        Input("model-dropdown", "value"),
    ) do model_name
        model = model_options[model_name]
        params = model.params

        param_inputs = html_div(
            style = Dict(
                "display" => "grid",
                "gridTemplateColumns" => "repeat(auto-fill, minmax(200px, 1fr))",
                "gap" => "16px",
                "padding" => "8px 0 20px 0",
            ),
        ) do
            [
                html_div(
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
                            id = (type = "param-input", index = pname),
                            type = "number",
                            value = pval,
                            debounce = true,
                            style = dcc_input_style
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


    callback!(
        app,
        Output("solution-output", "children"),
        Input("model-dropdown", "value"),
        Input((type = "param-input", index = ALL), "value"),
        State("param-names-store", "data"),
    ) do model_name, param_values, param_names
        # On initial load or when model just changed, param_names may be nothing
        # or param_values may be empty — solve with defaults in that case
        p = model_options[model_name]

        if !isnothing(param_names) && !isempty(param_values) && length(param_names) == length(param_values)
            # Check that all values are valid numbers (not nothing/missing)
            if all(v -> v isa Number, param_values)
                new_params = Dict(Symbol(k) => Float64(v) for (k, v) in zip(param_names, param_values))
                p = Static.Parametrization(p.model, new_params, p.u0)
            end
        end

        sol = Static.solve_model(p)
        solution_component(sol)
    end

    return nothing
end
