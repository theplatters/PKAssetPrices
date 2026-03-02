function get_app(model_options::Dict{String, Static.Parametrization})
    app = dash(
        suppress_callback_exceptions = true,
    )

    app.layout = html_div(
        [
            dcc_tabs(
                id = "tabs-model", value = "tab-1", children = [
                    dcc_tab(label = "Model explorer", value = "tab-1"),
                    dcc_tab(label = "Comparisons", value = "tab-2"),
                ]
            ),
            html_div(id = "tabs-content"),
        ]
    )

    return app
end



function register_comparison_callbacks!(app, model_options)
    # ── 1. Add-model button: increase counter & re-render columns ──
    callback!(
        app,
        Output("cmp-columns-container", "children"),
        Output("cmp-num-models", "data"),
        Input("cmp-add-model-btn", "n_clicks"),
        State("cmp-num-models", "data"),
    ) do n_clicks, current_n
        n = current_n + (n_clicks > 0 ? 1 : 0)
        # Guard: at least 2, cap at 6
        n = clamp(n, 2, 6)
        cols = [model_column(model_options, i) for i in 1:n]
        push!(cols, add_model_button())
        return cols, n
    end

    # ── 2. Per-column: when model dropdown changes → render param inputs ──
    callback!(
        app,
        Output((type = "cmp-param-container", index = MATCH), "children"),
        Output((type = "cmp-param-names-store", index = MATCH), "data"),
        Input((type = "cmp-model-dropdown", index = MATCH), "value"),
    ) do model_name
        isnothing(model_name) && return ([], [])
        model = model_options[model_name]
        params = model.params

        param_inputs = html_div(
            style = Dict(
                "display"             => "grid",
                "gridTemplateColumns" => "repeat(auto-fill, minmax(160px, 1fr))",
                "gap"                 => "12px",
                "padding"             => "8px 0 12px 0",
            ),
        ) do
            [
                html_div(
                    style = Dict(
                        "display"       => "flex",
                        "flexDirection" => "column",
                        "gap"           => "4px",
                    ),
                ) do
                    html_label(
                        "$pname",
                        style = Dict(
                            "fontWeight"     => "600",
                            "fontSize"       => "12px",
                            "color"          => "#6c757d",
                            "textTransform"  => "uppercase",
                            "letterSpacing"  => "0.6px",
                        ),
                    ),
                    dcc_input(
                        id = (type = "cmp-param-input", index = "$pname"),
                        type = "number",
                        value = pval,
                        debounce = true,
                        style = dcc_input_style,
                    )
                end
                for (pname, pval) in params
            ]
        end

        names_list = [pname for (pname, _) in params]
        return (param_inputs, names_list)
    end

    # ── 3. Master solve callback: collect ALL model selections + params → render tables & graphs ──
    callback!(
        app,
        Output("cmp-results-output", "children"),
        Input((type = "cmp-model-dropdown", index = ALL), "value"),
        Input((type = "cmp-param-input", index = ALL), "value"),
        State((type = "cmp-param-names-store", index = ALL), "data"),
        State("cmp-num-models", "data"),
    ) do model_names, all_param_values, all_param_names, num_models
        # ── Solve each model ──
        solutions = []
        labels    = String[]

        for i in 1:num_models
            mname = model_names[i]
            isnothing(mname) && continue

            p = model_options[mname]
            pnames = all_param_names[i]
            # Slice the flat param values for this column
            # (Each column's MATCH params are grouped by index order)
            if !isnothing(pnames) && !isempty(pnames)
                n_params = length(pnames)
                offset   = sum(length.(all_param_names[1:i-1])) + 1
                pvals    = all_param_values[offset:offset+n_params-1]
                if length(pvals) == n_params && all(v -> v isa Number, pvals)
                    new_params = Dict(Symbol(k) => Float64(v) for (k, v) in zip(pnames, pvals))
                    p = Static.Parametrization(p.model, new_params, p.u0)
                end
            end

            sol = Static.solve_model(p)
            push!(solutions, sol)
            push!(labels, "$mname (#$i)")
        end

        isempty(solutions) && return html_p("Select models above to compare.")

        return comparison_results(solutions, labels)
    end

    return nothing
end



function register_callbacks!(app, model_options)


    callback!(
        app,
        Output("tabs-content", "children"),
        Input("tabs-model", "value")
    ) do tab
        if tab == "tab-1"
            return model_explore(model_options)
        elseif tab == "tab-2"
            return comparisons(model_options)
        end
    end

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

    register_comparison_callbacks!(app, model_options)
    return nothing
end
