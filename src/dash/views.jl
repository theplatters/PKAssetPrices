function model_explore(model_options)
    return html_main(className = "dashboard-view") do
        view_heading(
            "Static model explorer",
            "Equilibrium notebook",
            "Select a specification, adjust its assumptions, and inspect the recomputed system.",
        ),
        html_div(className = "explorer-layout") do
            html_aside(className = "control-panel") do
                html_div(className = "control-panel-heading") do
                    html_div("Inputs", className = "eyebrow"),
                    html_h2("Model controls"),
                    html_p("Changes are solved when an input loses focus or you press Enter.")
                end,
                html_label("Specification", className = "control-label"),
                dcc_dropdown(
                    id = "model-dropdown",
                    options = dropdown_options(model_options),
                    value = default_model_name(model_options),
                    clearable = false,
                    className = "model-dropdown",
                ),
                html_div(className = "parameter-divider") do
                    html_span("Parameters"),
                    html_span("Value")
                end,
                html_div(id = "param-container")
            end,
            html_div(className = "output-column") do
                dcc_loading(
                    id = "solution-loading",
                    type = "circle",
                    color = COLORS.primary,
                    children = html_div(id = "solution-output"),
                    parent_className = "loading-container",
                )
            end
        end
    end
end

function comparisons(model_options)
    return html_main(className = "dashboard-view") do
        view_heading(
            "Static model comparison",
            "Comparative workbook",
            "Place specifications side by side to trace how assumptions move stocks, flows, and equilibrium curves.",
        ),
        dcc_store(id = "cmp-num-models", data = 2),
        html_section(className = "comparison-setup") do
            html_header(className = "comparison-setup-heading") do
                html_div() do
                    html_div("Inputs", className = "eyebrow"),
                    html_h2("Configurations"),
                    html_p("Compare up to six independently parameterized models.")
                end,
                add_model_button()
            end,
            html_div(
                [model_column(model_options, 1), model_column(model_options, 2)],
                id = "cmp-columns-container",
                className = "comparison-model-grid",
            )
        end,
        dcc_loading(
            id = "cmp-loading",
            type = "circle",
            color = COLORS.primary,
            children = html_div(id = "cmp-results-output"),
            parent_className = "loading-container",
        )
    end
end

function dynamic_explore(model_options)
    default_name = default_dynamic_model_name(model_options)
    default_model = model_options[default_name]
    period_count = length(default_model.model.time.grid)

    return html_main(className = "dashboard-view dynamic-view") do
        view_heading(
            "Dynamic systems",
            "Dynamics laboratory",
            "Run the discrete-time models as evolving systems and inspect their trajectories, ranges, and endpoints.",
        ),
        html_div(className = "dynamic-layout") do
            html_aside(className = "control-panel dynamic-control-panel") do
                html_div(className = "control-panel-heading") do
                    html_div("Simulation inputs", className = "eyebrow"),
                    html_h2("Dynamic controls"),
                    html_p("Parameter changes recompute the full path when an input loses focus.")
                end,
                html_label("Dynamic specification", className = "control-label"),
                dcc_dropdown(
                    id = "dynamic-model-dropdown",
                    options = dynamic_dropdown_options(model_options),
                    value = default_name,
                    clearable = false,
                    className = "model-dropdown dynamic-model-dropdown",
                ),
                html_label("Simulation periods", className = "control-label"),
                dcc_input(
                    id = "dynamic-horizon-input",
                    type = "number",
                    value = period_count,
                    min = 2,
                    max = period_count,
                    step = 1,
                    debounce = true,
                    className = "parameter-input horizon-input",
                ),
                html_div(className = "parameter-divider dynamic-parameter-divider") do
                    html_span("Parameters"),
                    html_span("Value")
                end,
                html_div(id = "dynamic-param-container")
            end,
            html_div(className = "dynamic-output-column") do
                html_section(className = "series-selector-panel") do
                    html_div() do
                        html_div("Output selection", className = "eyebrow"),
                        html_h2("Observed trajectories")
                    end,
                    dcc_dropdown(
                        id = "dynamic-variable-dropdown",
                        options = dynamic_variable_options(default_model),
                        value = default_dynamic_variables(default_model),
                        multi = true,
                        clearable = true,
                        className = "dynamic-variable-dropdown",
                    )
                end,
                dcc_loading(
                    id = "dynamic-solution-loading",
                    type = "circle",
                    color = COLORS.accent,
                    children = html_div(id = "dynamic-solution-output"),
                    parent_className = "loading-container dynamic-loading-container",
                )
            end
        end
    end
end
