const SOLVE_CACHE = Dict{UInt, Static.Solution}()
const SOLVE_CACHE_LOCK = ReentrantLock()
const SOLVE_CACHE_LIMIT = 128

function solve_cached(parametrization::Static.Parametrization)
    key = hash((parametrization.model.equations, parametrization.params, parametrization.u0))
    return lock(SOLVE_CACHE_LOCK) do
        if !haskey(SOLVE_CACHE, key) && length(SOLVE_CACHE) >= SOLVE_CACHE_LIMIT
            delete!(SOLVE_CACHE, first(keys(SOLVE_CACHE)))
        end
        get!(SOLVE_CACHE, key) do
            Static.solve_model(parametrization)
        end
    end
end

function app_layout(model_options, dynamic_model_options)
    parameter_store = Dict(
        name => parameter_names(parametrization)
        for (name, parametrization) in model_options
    )
    dynamic_parameter_store = Dict(
        name => dynamic_parameter_names(parametrization)
        for (name, parametrization) in dynamic_model_options
    )

    return html_div(className = "app-frame") do
        workbook_header(),
        html_nav(className = "workbook-navigation", aria_label = "Workbook sections") do
            dcc_tabs(
                id = "tabs-model",
                value = "explorer",
                className = "workbook-tabs",
                parent_className = "workbook-tabs-parent",
                children = [
                    dcc_tab(
                        label = "Static explorer",
                        value = "explorer",
                        className = "workbook-tab",
                        selected_className = "workbook-tab--selected",
                    ),
                    dcc_tab(
                        label = "Static comparison",
                        value = "comparisons",
                        className = "workbook-tab",
                        selected_className = "workbook-tab--selected",
                    ),
                    dcc_tab(
                        label = "Dynamics lab",
                        value = "dynamics",
                        className = "workbook-tab dynamic-tab",
                        selected_className = "workbook-tab--selected dynamic-tab--selected",
                    ),
                ],
            )
        end,
        html_div(id = "tabs-content"),
        dcc_store(id = "param-names-store", data = parameter_store),
        dcc_store(id = "dynamic-param-names-store", data = dynamic_parameter_store)
    end
end

function get_app(
    model_options::Dict{String, Static.Parametrization},
    dynamic_model_options = default_dynamic_models(),
)
    app = dash(
        suppress_callback_exceptions = true,
        assets_folder = joinpath(@__DIR__, "assets"),
        update_title = "Solving model…",
    )
    app.title = "PK Asset Prices · Model Workbook"
    app.layout = app_layout(model_options, dynamic_model_options)
    return app
end
