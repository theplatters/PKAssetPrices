function register_dynamic_callbacks!(app, model_options)
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
        Input("dynamic-horizon-input", "value"),
        Input("dynamic-variable-dropdown", "value"),
        State("dynamic-param-names-store", "data"),
    ) do model_name, parameter_values, _, horizon, selected_variables, all_parameter_names
        haskey(model_options, model_name) || return empty_state(
            "Dynamic model unavailable",
            "Select a dynamic specification to run its simulation.",
        )

        base = model_options[model_name]
        configured = dynamic_parametrization_with_values(
            base,
            all_parameter_names[model_name],
            parameter_values,
        )
        period_count = horizon isa Real && isfinite(horizon) ?
            horizon : length(base.model.time.grid)
        configured = dynamic_parametrization_with_horizon(configured, period_count)
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
