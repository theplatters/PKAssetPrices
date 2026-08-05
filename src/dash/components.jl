"""Return model names in a stable, human-friendly order."""
function ordered_model_names(model_options)
    names = sort!(collect(keys(model_options)))
    baseline_index = findfirst(==("Baseline"), names)
    isnothing(baseline_index) || insert!(names, 1, popat!(names, baseline_index))
    return names
end

default_model_name(model_options) = first(ordered_model_names(model_options))

function parameter_names(parametrization::Static.Parametrization)
    configured = Set(keys(parametrization.params))
    names = [name for name in parametrization.model.parameters if name in configured]
    append!(names, sort!(collect(setdiff(configured, Set(names)))))
    return string.(names)
end

dropdown_options(model_options) = [
    (label = name, value = name) for name in ordered_model_names(model_options)
]

function workbook_header()
    return html_header(className = "workbook-masthead") do
        html_div(className = "brand-lockup") do
            html_div("PK", className = "brand-mark"),
            html_div() do
                html_div("Post-Keynesian Model Lab", className = "brand-name"),
                html_div("Interactive equilibrium workbook", className = "brand-subtitle")
            end
        end,
        html_div(className = "masthead-meta") do
            html_span(className = "status-dot"),
            html_span("Julia · Equilibrium + dynamics")
        end
    end
end

function view_heading(kicker, title, description)
    return html_header(className = "view-heading") do
        html_div(kicker, className = "eyebrow"),
        html_h1(title),
        html_p(description)
    end
end

function section_heading(kicker, title; description = nothing, level = 2)
    title_component = level == 3 ? html_h3(title) : html_h2(title)
    children = Any[html_div(kicker, className = "eyebrow"), title_component]
    isnothing(description) || push!(children, html_p(description))
    return html_header(children, className = "section-heading")
end

function empty_state(title, message)
    return html_div(className = "empty-state") do
        html_div("∅", className = "empty-state-symbol"),
        html_h3(title),
        html_p(message)
    end
end

function param_inputs(
    param_names,
    params,
    param_descriptions;
    id = name -> (type = "param-input", index = name),
)
    inputs = map(param_names) do name
        symbol = Symbol(name)
        description = get(param_descriptions, symbol, "Model parameter $(name)")

        html_div(className = "parameter-field", title = description) do
            html_div(className = "parameter-label-row") do
                html_label(name),
                html_span("ⓘ", className = "parameter-help", title = description)
            end,
            dcc_input(
                id = id(name),
                type = "number",
                value = params[symbol],
                debounce = true,
                className = "parameter-input",
            )
        end
    end

    return html_div(inputs, className = "parameter-grid")
end

get_param_input(param_names, params, param_descriptions) =
    param_inputs(param_names, params, param_descriptions)

function model_column(model_options, index::Int)
    return html_article(
        id = (type = "cmp-col", index),
        className = "comparison-model-card",
    ) do
        html_div(className = "model-card-heading") do
            html_span(lpad(string(index), 2, '0'), className = "model-index"),
            html_h3("Model configuration")
        end,
        html_label("Specification", className = "control-label"),
        dcc_dropdown(
            id = (type = "cmp-model-dropdown", index),
            options = dropdown_options(model_options),
            value = default_model_name(model_options),
            clearable = false,
            className = "model-dropdown",
        ),
        html_div(id = (type = "cmp-param-container", index), className = "comparison-parameters")
    end
end

function add_model_button()
    return html_button(
        [html_span("+", className = "button-icon"), html_span("Add model")],
        id = "cmp-add-model-btn",
        n_clicks = 0,
        className = "add-model-button",
        title = "Add another model configuration (maximum six)",
    )
end
