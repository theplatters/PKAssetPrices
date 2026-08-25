function register_dynamic_callbacks!(app, model_options)
    callback!(
        app,
        Output("dynamic-shock-rows-store", "data"),
        Input("dynamic-model-dropdown", "value"),
        Input("dynamic-shock-add", "n_clicks"),
        Input((type = "dynamic-shock-remove", index = ALL), "n_clicks"),
        State("dynamic-shock-rows-store", "data"),
    ) do model_name, _, _, current_rows
        triggered = isempty(callback_context().triggered) ? nothing : callback_context().triggered[1]
        trigger = isnothing(triggered) ? "" : triggered.prop_id
        occursin("dynamic-model-dropdown", trigger) && return Int[]
        rows = if current_rows isa AbstractVector
            Int[round(Int, x) for x in current_rows
                if x isa Integer || (x isa Real && isfinite(x) && x == round(x))]
        else
            Int[]
        end
        if occursin("dynamic-shock-add", trigger)
            return vcat(rows, isempty(rows) ? 1 : maximum(rows) + 1)
        end
        match_result = match(r"\"index\"\s*:\s*(-?\d+)", trigger)
        isnothing(match_result) && return rows
        # Dash can invoke an ALL-pattern callback when a newly rendered remove
        # button enters the layout with n_clicks=0.  Only an actual click may
        # remove a row; otherwise the row just added would disappear again.
        click_count = triggered.value
        click_count isa Real && !(click_count isa Bool) && click_count >= 1 || return rows
        removed = parse(Int, match_result.captures[1])
        return [row for row in rows if row != removed]
    end

    callback!(
        app,
        Output("dynamic-shock-rows-container", "children"),
        Input("dynamic-model-dropdown", "value"),
        Input("dynamic-shock-rows-store", "data"),
    ) do model_name, row_ids
        haskey(model_options, model_name) || return html_div()
        ids = row_ids isa AbstractVector ? row_ids : Int[]
        return [dynamic_shock_row(model_options[model_name], index) for index in ids]
    end

    callback!(
        app,
        Output("dynamic-param-container", "children"),
        Output("dynamic-variable-dropdown", "options"),
        Output("dynamic-variable-dropdown", "value"),
        Output("dynamic-horizon-input", "max"),
        Output("dynamic-horizon-input", "value"),
        Input("dynamic-model-dropdown", "value"),
        State("dynamic-param-names-store", "data"),
    ) do model_name, all_parameter_names
        haskey(model_options, model_name) || return html_div(), [], [], 2, 2
        parametrization = model_options[model_name]
        period_count = length(parametrization.model.time.grid)
        parameter_component = param_inputs(
            all_parameter_names[model_name],
            parametrization.params,
            dynamic_parameter_descriptions(parametrization);
            id = name -> (type = "dynamic-param-input", index = name),
        )
        return (
            parameter_component,
            dynamic_variable_options(parametrization),
            default_dynamic_variables(parametrization),
            period_count,
            period_count,
        )
    end

    callback!(
        app,
        Output("dynamic-solution-output", "children"),
        Input("dynamic-model-dropdown", "value"),
        Input((type = "dynamic-param-input", index = ALL), "value"),
        Input("dynamic-param-container", "children"),
        Input((type = "dynamic-shock-param", index = ALL), "value"),
        Input((type = "dynamic-shock-from", index = ALL), "value"),
        Input((type = "dynamic-shock-until", index = ALL), "value"),
        Input((type = "dynamic-shock-value", index = ALL), "value"),
        Input("dynamic-horizon-input", "value"),
        Input("dynamic-variable-dropdown", "value"),
        State("dynamic-param-names-store", "data"),
    ) do model_name, parameter_values, _, shock_params, shock_froms, shock_untils,
        shock_values, horizon, selected_variables, all_parameter_names
        haskey(model_options, model_name) || return empty_state(
            "Dynamic model unavailable",
            "Select a dynamic specification to run its simulation.",
        )

        base = model_options[model_name]
        variables = if isnothing(selected_variables)
            String[]
        elseif selected_variables isa AbstractVector
            selected_variables
        else
            [selected_variables]
        end
        isempty(variables) && return empty_state(
            "No trajectories selected",
            "Choose one or more variables to inspect their paths through time.",
        )

        try
            configured = dynamic_parametrization_with_values(
                base, all_parameter_names[model_name], parameter_values)
            shock_vector = dynamic_shocks_from_rows(
                base, shock_params, shock_froms, shock_untils, shock_values)
            configured = Dynamic.set_shocks(configured, shock_vector)
            period_count = horizon isa Real && isfinite(horizon) ?
                horizon : length(base.model.time.grid)
            configured = dynamic_parametrization_with_horizon(configured, period_count)
            solution = solve_dynamic_cached(configured)
            return dynamic_solution_component(solution, variables)
        catch error
            @error "Dynamic dashboard simulation failed" model_name exception = (
                error,
                catch_backtrace(),
            )
            return html_div(className = "simulation-error") do
                html_div("Simulation interrupted", className = "eyebrow"),
                html_h3("The selected parameterization did not converge."),
                html_p("Restore the default values or shorten the simulation horizon and try again.")
            end
        end
    end
    return nothing
end
