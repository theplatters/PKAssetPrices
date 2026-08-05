function parametrization_with_values(parametrization, names, values)
    length(names) == length(values) || return parametrization
    all(value -> value isa Number, values) || return parametrization

    parameters = copy(parametrization.params)
    for (name, value) in zip(names, values)
        parameters[Symbol(name)] = Float64(value)
    end
    return Static.Parametrization(parametrization.model, parameters, parametrization.u0)
end

function component_id_value(id, key::Symbol)
    id isa NamedTuple && return getproperty(id, key)
    haskey(id, key) && return id[key]
    return id[string(key)]
end

function register_comparison_callbacks!(app, model_options)
    callback!(
        app,
        Output("cmp-columns-container", "children"),
        Output("cmp-num-models", "data"),
        Input("cmp-add-model-btn", "n_clicks"),
        State("cmp-columns-container", "children"),
        State("cmp-num-models", "data"),
    ) do clicks, current_columns, current_count
        columns = isnothing(current_columns) ? Any[] : collect(current_columns)
        existing_count = isnothing(current_count) ? max(length(columns), 2) : Int(current_count)
        requested_count = clamp(2 + something(clicks, 0), 2, 6)
        model_count = max(existing_count, requested_count)

        while length(columns) < model_count
            push!(columns, model_column(model_options, length(columns) + 1))
        end
        return columns, model_count
    end

    callback!(
        app,
        Output((type = "cmp-param-container", index = MATCH), "children"),
        Input((type = "cmp-model-dropdown", index = MATCH), "value"),
        State((type = "cmp-model-dropdown", index = MATCH), "id"),
        State("param-names-store", "data"),
    ) do model_name, model_id, all_parameter_names
        haskey(model_options, model_name) || return html_div()
        parametrization = model_options[model_name]
        column_index = component_id_value(model_id, :index)
        return param_inputs(
            all_parameter_names[model_name],
            parametrization.params,
            parametrization.model.parameter_descriptions;
            id = name -> (type = "cmp-param-input", model = column_index, index = name),
        )
    end

    callback!(
        app,
        Output("cmp-results-output", "children"),
        Input((type = "cmp-param-container", index = ALL), "children"),
        Input((type = "cmp-model-dropdown", index = ALL), "value"),
        Input((type = "cmp-param-input", model = ALL, index = ALL), "value"),
        State((type = "cmp-param-input", model = ALL, index = ALL), "id"),
        State("cmp-num-models", "data"),
    ) do _, model_names, parameter_values, parameter_ids, model_count
        configured = Dict{Int, Dict{Symbol, Float64}}()
        for (id, value) in zip(parameter_ids, parameter_values)
            value isa Number || continue
            column = Int(component_id_value(id, :model))
            name = Symbol(component_id_value(id, :index))
            configured_parameters = get!(configured, column, Dict{Symbol, Float64}())
            configured_parameters[name] = Float64(value)
        end

        solutions = Static.Solution[]
        labels = String[]
        available_count = min(Int(model_count), length(model_names))
        for column in 1:available_count
            model_name = model_names[column]
            haskey(model_options, model_name) || continue
            base = model_options[model_name]
            parameters = copy(base.params)
            merge!(parameters, get(configured, column, Dict{Symbol, Float64}()))
            parametrization = Static.Parametrization(base.model, parameters, base.u0)
            push!(solutions, solve_cached(parametrization))
            push!(labels, "$(model_name) · $(lpad(string(column), 2, '0'))")
        end

        isempty(solutions) && return empty_state(
            "No models selected",
            "Choose at least one valid model configuration to compare.",
        )
        return comparison_results(solutions, labels)
    end
    return nothing
end

function register_callbacks!(
    app,
    model_options,
    dynamic_model_options = default_dynamic_models(),
)
    callback!(
        app,
        Output("tabs-content", "children"),
        Input("tabs-model", "value"),
    ) do tab
        tab == "comparisons" && return comparisons(model_options)
        tab == "dynamics" && return dynamic_explore(dynamic_model_options)
        return model_explore(model_options)
    end

    callback!(
        app,
        Output("param-container", "children"),
        Input("model-dropdown", "value"),
        State("param-names-store", "data"),
    ) do model_name, all_parameter_names
        haskey(model_options, model_name) || return html_div()
        parametrization = model_options[model_name]
        return get_param_input(
            all_parameter_names[model_name],
            parametrization.params,
            parametrization.model.parameter_descriptions,
        )
    end

    callback!(
        app,
        Output("solution-output", "children"),
        Input("model-dropdown", "value"),
        Input((type = "param-input", index = ALL), "value"),
        Input("param-container", "children"),
        State("param-names-store", "data"),
    ) do model_name, parameter_values, _, all_parameter_names
        haskey(model_options, model_name) || return empty_state(
            "Model unavailable",
            "Select a model specification to compute its equilibrium.",
        )
        base = model_options[model_name]
        parametrization = parametrization_with_values(
            base,
            all_parameter_names[model_name],
            parameter_values,
        )
        return solution_component(solve_cached(parametrization))
    end

    register_comparison_callbacks!(app, model_options)
    register_dynamic_callbacks!(app, dynamic_model_options)
    return nothing
end
