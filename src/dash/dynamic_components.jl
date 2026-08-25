const DYNAMIC_SOLVE_CACHE = Dict{UInt, Dynamic.DynamicSolution}()
const DYNAMIC_SOLVE_CACHE_LOCK = ReentrantLock()
const DYNAMIC_SOLVE_CACHE_LIMIT = 64
const DYNAMIC_PLOT_COLORS = [
    COLORS.accent,
    COLORS.teal,
    COLORS.primary,
    "#8a6f3d",
    "#725b83",
    "#5f7481",
]

function default_dynamic_models()
    return Dict{String, Dynamic.DynamicParametrization}(
        "Working model" => Dynamic.WorkingModel,
        "Quantity accumulation" => Dynamic.DynQ,
        "Turnover feedback" => Dynamic.Dynα,
        "Turnover and quantity" => Dynamic.DynαQ,
        "Credit-rationing feedback" => Dynamic.DynαQCr,
    )
end

function ordered_dynamic_model_names(model_options)
    names = sort!(collect(keys(model_options)))
    working_index = findfirst(==("Working model"), names)
    isnothing(working_index) || insert!(names, 1, popat!(names, working_index))
    return names
end

default_dynamic_model_name(model_options) = first(ordered_dynamic_model_names(model_options))

dynamic_dropdown_options(model_options) = [
    (label = name, value = name) for name in ordered_dynamic_model_names(model_options)
]

dynamic_parameter_names(parametrization::Dynamic.DynamicParametrization) =
    string.([parameter.name for parameter in parametrization.model.params])

dynamic_parameter_descriptions(parametrization::Dynamic.DynamicParametrization) = Dict(
    parameter.name => parameter.desc for parameter in parametrization.model.params
)

function dynamic_shock_row(parametrization::Dynamic.DynamicParametrization, index)
    options = [(label = isempty(parameter.desc) ? string(parameter.name) : parameter.desc,
                value = string(parameter.name)) for parameter in parametrization.model.params]
    first_parameter = first(parametrization.model.params).name
    return html_div(className = "dynamic-shock-row") do
        dcc_dropdown(id = (type = "dynamic-shock-param", index = index),
            options = options, value = string(first_parameter), clearable = false,
            className = "dynamic-shock-param"),
        dcc_input(id = (type = "dynamic-shock-from", index = index), type = "number",
            value = 0, className = "parameter-input"),
        dcc_input(id = (type = "dynamic-shock-until", index = index), type = "number",
            placeholder = "persistent", className = "parameter-input"),
        dcc_input(id = (type = "dynamic-shock-value", index = index), type = "number",
            value = parametrization.params[first_parameter], className = "parameter-input"),
        html_button("×", id = (type = "dynamic-shock-remove", index = index), n_clicks = 0,
            className = "dynamic-shock-remove", title = "Remove shock")
    end
end

_finite_dashboard_real(x) = x isa Real && !(x isa Bool) && isfinite(x)

function dynamic_shocks_from_rows(base::Dynamic.DynamicParametrization, params, froms, untils, values)
    declared = Set(parameter.name for parameter in base.model.params)
    grid = base.model.time.grid
    shocks = Dynamic.Shock[]
    seen = Set{Tuple{Symbol,Float64,Union{Float64,Nothing},Float64}}()
    for (param, from, until, value) in zip(params, froms, untils, values)
        symbol = try
            param isa Symbol ? param : Symbol(String(param))
        catch
            continue
        end
        symbol in declared && _finite_dashboard_real(from) && _finite_dashboard_real(value) || continue
        clean_until = if until === nothing || until === "" ||
                (until isa AbstractString && isempty(strip(until)))
            nothing
        elseif _finite_dashboard_real(until)
            until
        else
            continue
        end
        clean_until !== nothing && clean_until < from && continue
        from > last(grid) && continue
        clean_until !== nothing && clean_until < first(grid) && continue
        key = (symbol, Float64(from), clean_until === nothing ? nothing : Float64(clean_until), Float64(value))
        key in seen && continue
        push!(seen, key)
        push!(shocks, Dynamic.Shock(param = symbol, from = from, until = clean_until,
            value = value, source = "dashboard shock row"))
    end
    return shocks
end

function dynamic_variable_options(parametrization::Dynamic.DynamicParametrization)
    return [
        (
            label = isempty(variable.desc) ? string(variable.name) : variable.desc,
            value = string(variable.name),
        )
        for variable in parametrization.model.variables
    ]
end

function default_dynamic_variables(parametrization::Dynamic.DynamicParametrization)
    available = Set(variable.name for variable in parametrization.model.variables)
    preferred = [:Y, :AP, :AD, :AS]
    selected = [variable for variable in preferred if variable in available]
    if isempty(selected)
        variables = [variable.name for variable in parametrization.model.variables]
        append!(selected, variables[1:min(4, length(variables))])
    end
    return string.(selected)
end

function dynamic_parametrization_with_values(parametrization, names, values)
    length(names) == length(values) || return parametrization
    all(value -> value isa Number, values) || return parametrization

    parameters = copy(parametrization.params)
    for (name, value) in zip(names, values)
        parameters[Symbol(name)] = Float64(value)
    end
    return Dynamic.DynamicParametrization(
        parametrization.model,
        parameters,
        parametrization.init,
        parametrization.u0,
        deepcopy(parametrization.shocks),
    )
end

function dynamic_parametrization_with_horizon(parametrization, horizon)
    full_grid = parametrization.model.time.grid
    period_count = clamp(round(Int, horizon), 2, length(full_grid))
    period_count == length(full_grid) && return parametrization

    model = parametrization.model
    truncated_model = Dynamic.DynamicModel(
        time = Dynamic.DiscreteTime(full_grid[1:period_count]),
        variables = model.variables,
        params = model.params,
        equations = model.equations,
        nulls = model.nulls,
        eval = model.eval,
        stocks = model.stocks,
        stocks_eval = model.stocks_eval,
        balance_sheets = model.balance_sheets,
        sheet_eval = model.sheet_eval,
    )
    return Dynamic.DynamicParametrization(
        truncated_model,
        parametrization.params,
        parametrization.init,
        parametrization.u0,
        deepcopy(parametrization.shocks),
    )
end

function solve_dynamic_cached(parametrization::Dynamic.DynamicParametrization)
    key = hash((
        parametrization.model.equations,
        parametrization.model.stocks,
        parametrization.model.balance_sheets,
        parametrization.model.time.grid,
        parametrization.params,
        parametrization.init,
        parametrization.u0,
        parametrization.shocks,
    ))
    return lock(DYNAMIC_SOLVE_CACHE_LOCK) do
        if !haskey(DYNAMIC_SOLVE_CACHE, key) &&
                length(DYNAMIC_SOLVE_CACHE) >= DYNAMIC_SOLVE_CACHE_LIMIT
            delete!(DYNAMIC_SOLVE_CACHE, first(keys(DYNAMIC_SOLVE_CACHE)))
        end
        get!(DYNAMIC_SOLVE_CACHE, key) do
            Dynamic.solve_model(parametrization)
        end
    end
end

function dynamic_variable_description(solution::Dynamic.DynamicSolution, variable::Symbol)
    index = findfirst(item -> item.name == variable, solution.model.model.variables)
    isnothing(index) && return string(variable)
    description = solution.model.model.variables[index].desc
    return isempty(description) ? string(variable) : description
end

function dynamic_path_component(
    solution::Dynamic.DynamicSolution,
    variable::Symbol,
    color_index::Int,
)
    time = solution.model.model.time.grid
    path = solution.paths[variable]
    description = dynamic_variable_description(solution, variable)
    color = DYNAMIC_PLOT_COLORS[mod1(color_index, length(DYNAMIC_PLOT_COLORS))]

    trace = (
        x = time,
        y = path,
        type = "scatter",
        mode = "lines",
        name = string(variable),
        hovertemplate = "t %{x:g}<br>$(variable) %{y:.4f}<extra></extra>",
        line = Dict("color" => color, "width" => 2.25),
    )
    endpoint = (
        x = [last(time)],
        y = [last(path)],
        type = "scatter",
        mode = "markers",
        name = "Final value",
        hovertemplate = "Final %{y:.4f}<extra></extra>",
        marker = Dict(
            "color" => color,
            "size" => 7,
            "line" => Dict("color" => COLORS.paper, "width" => 1.5),
        ),
        showlegend = false,
    )

    layout = get_layout(
        title = "$(description) · $(variable)",
        xaxis_title = Dict("text" => "Period, t"),
        yaxis_title = Dict("text" => string(variable)),
        show_annotation = false,
    )
    layout["showlegend"] = false
    layout["hovermode"] = "x unified"
    layout["margin"] = Dict("l" => 58, "r" => 18, "t" => 58, "b" => 50)

    return html_article(className = "dynamic-chart-card") do
        html_div(className = "trajectory-rule") do
            html_span("t₀  $(format_value(first(path); digits = 3))"),
            html_span("tₙ  $(format_value(last(path); digits = 3))")
        end,
        dcc_graph(
            figure = Dict("data" => [trace, endpoint], "layout" => layout),
            config = Dict(
                "displayModeBar" => true,
                "displaylogo" => false,
                "responsive" => true,
                "modeBarButtonsToRemove" => ["lasso2d", "select2d", "autoScale2d"],
                "toImageButtonOptions" => Dict(
                    "format" => "svg",
                    "filename" => "dynamic-$(variable)-trajectory",
                ),
            ),
            className = "dynamic-graph",
        )
    end
end

function dynamic_endpoint_table(solution::Dynamic.DynamicSolution, variables)
    rows = map(variables) do variable
        path = solution.paths[variable]
        initial = first(path)
        final = last(path)
        change = final - initial
        percent_change = iszero(initial) ? "—" : "$(format_value(100 * change / abs(initial); digits = 1))%"
        html_tr(title = dynamic_variable_description(solution, variable)) do
            html_th(string(variable), scope = "row"),
            html_td(format_value(initial; digits = 4), className = "numeric-cell"),
            html_td(format_value(final; digits = 4), className = "numeric-cell"),
            html_td(format_value(change; digits = 4), className = "numeric-cell"),
            html_td(percent_change, className = "numeric-cell"),
            html_td(format_value(minimum(path); digits = 4), className = "numeric-cell"),
            html_td(format_value(maximum(path); digits = 4), className = "numeric-cell")
        end
    end

    return html_div(className = "table-scroll") do
        html_table(className = "data-table dynamic-endpoint-table") do
            html_thead() do
                html_tr() do
                    html_th("Series"),
                    html_th("Initial", className = "numeric-cell"),
                    html_th("Final", className = "numeric-cell"),
                    html_th("Δ", className = "numeric-cell"),
                    html_th("Δ %", className = "numeric-cell"),
                    html_th("Minimum", className = "numeric-cell"),
                    html_th("Maximum", className = "numeric-cell")
                end
            end,
            html_tbody(rows)
        end
    end
end

function dynamic_solution_component(solution::Dynamic.DynamicSolution, selected_variables)
    available = keys(solution.paths)
    variables = [Symbol(variable) for variable in selected_variables if Symbol(variable) in available]
    isempty(variables) && return empty_state(
        "No trajectories selected",
        "Choose one or more variables to inspect their paths through time.",
    )

    time = solution.model.model.time.grid
    charts = [
        dynamic_path_component(solution, variable, index)
        for (index, variable) in enumerate(variables)
    ]

    return html_div(className = "dynamic-workbook") do
        html_div(className = "dynamic-summary") do
            html_div() do
                html_span(string(length(time)), className = "summary-value"),
                html_span("simulated periods", className = "summary-label")
            end,
            html_div() do
                html_span(string(length(solution.paths)), className = "summary-value"),
                html_span("state and flow paths", className = "summary-label")
            end,
            html_div() do
                html_span(
                    "$(format_value(first(time); digits = 1)) → $(format_value(last(time); digits = 1))",
                    className = "summary-value dynamic-time-value",
                ),
                html_span("model time domain", className = "summary-label")
            end
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "01 · Trajectories",
                "Paths through model time";
                description = "Each panel retains its own scale so differently sized series remain legible.",
            ),
            html_div(charts, className = "dynamic-chart-grid")
        end,
        html_section(className = "workbook-section") do
            section_heading(
                "02 · Endpoint ledger",
                "Change over the simulation window";
                description = "Initial, final, and range statistics for the selected trajectories.",
            ),
            html_article(className = "paper-panel dynamic-ledger") do
                dynamic_endpoint_table(solution, variables)
            end
        end
    end
end
