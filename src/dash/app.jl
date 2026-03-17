const SOLVE_CACHE = Dict{UInt, Solution}()
const COMPONENT_CACHE = Dict{UInt, Dash.Component}()


function get_app(model_options::Dict{String, Static.Parametrization})

    @async for p in values(model_options)
        solve_cached(p)
    end


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
            dcc_store(
                id = "param-names-store",
                data = Dict(name => keys(v.params) for (name, v) in model_options),
            ),
        ]
    )

    return app

end

function solve_cached(p::Static.Parametrization)
    key = hash((p.model.equations, p.params, p.u0))
    return get!(SOLVE_CACHE, key) do
        Static.solve_model(p)
    end
end

function get_param_input(param_names, params)
    key = hash(param_names)
    return get!(COMPONENT_CACHE, key) do
        param_inputs(param_names, params)
    end
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
        Input((type = "cmp-model-dropdown", index = MATCH), "value"),
        State((type = "cmp-model-dropdown", index = MATCH), "id"),
        State("param-names-store", "data"),
    ) do model_name, model_id, param_names
        isnothing(model_name) && return ([], [])
        model = model_options[model_name]
        params = param_names[model_name]

        param_inputs = html_div(
            style = Dict(
                "display" => "grid",
                "gridTemplateColumns" => "repeat(auto-fill, minmax(160px, 1fr))",
                "gap" => "12px",
                "padding" => "8px 0 12px 0",
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
                            id = (type = "cmp-param-input", model = model_id["index"], index = "$pname"),
                            type = "number",
                            value = model.params[Symbol(pname)],
                            debounce = true,
                            style = dcc_input_style,
                        )
                end
                    for pname in params
            ]
        end

        return (param_inputs)
    end

    # ── 3. Master solve callback: collect ALL model selections + params → render tables & graphs ──
    callback!(
        app,
        Output("cmp-results-output", "children"),
        Input((type = "cmp-param-container", index = ALL), "children"),
        Input((type = "cmp-model-dropdown", index = ALL), "value"),
        Input((type = "cmp-param-input", model = ALL, index = ALL), "value"),
        State((type = "cmp-param-input", model = ALL, index = ALL), "id"),
        State("param-names-store", "data"),
        State("cmp-num-models", "data"),
    ) do _, model_names, all_param_values, all_param_ids, all_param_names, num_models
        # ── Solve each model ──
        solutions = []
        labels = String[]

        new_params = [copy(model_options[mname].params) for mname in model_names]
        for (id, val) in zip(all_param_ids, all_param_values)
            new_params[id.model][Symbol(id.index)] = val
        end

        for i in 1:num_models
            mname = model_names[i]
            isnothing(mname) && continue

            p = model_options[mname]
            pnames = all_param_names[mname]
            # Slice the flat param values for this column
            # (Each column's MATCH params are grouped by index order)
            if !isnothing(pnames) && !isempty(pnames)
                p = Static.Parametrization(p.model, new_params[i], p.u0)
            end

            sol = solve_cached(p)
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
        State("param-names-store", "data"),
    ) do model_name, param_names_store
        model = model_options[model_name]
        param_names = param_names_store[model_name]
        params = model.params


        return vcat(get_param_input(param_names, params))
    end


    callback!(
        app,
        Output("solution-output", "children"),
        Input("model-dropdown", "value"),
        Input((type = "param-input", index = ALL), "value"),
        Input("param-container", "children"),  # ensures ordering
        State("param-names-store", "data"),
    ) do model_name, param_values, _, param_names_store
        # On initial load or when model just changed, param_names may be nothing
        # or param_values may be empty — solve with defaults in that case
        p = model_options[model_name]
        param_names = param_names_store[model_name]


        if !isnothing(param_names) && !isempty(param_values) && length(param_names) == length(param_values)
            # Check that all values are valid numbers (not nothing/missing)
            if all(v -> v isa Number, param_values)
                new_params = Dict(Symbol(k) => Float64(v) for (k, v) in zip(param_names, param_values))
                p::Static.Parametrization = Static.Parametrization(p.model, new_params, p.u0)
            end
        end

        solve_cached(p) |> solution_component
    end

    register_comparison_callbacks!(app, model_options)
    return nothing
end
