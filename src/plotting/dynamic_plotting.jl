module Plotting
using CairoMakie
using ..Dynamic
using ..Dynamic: DynamicModel, DiscreteTime, DynamicParametrization, solve_model, @model

function run_dynq_case(; model = Dynamic.Dynamic.DynQconAPLevelChange2, overwrites = (;), init_vals = (;))
    params = copy(model.params)

    for (k, v) in overwrites
        if haskey(params, k)
            params[k] = v
        else
            error("Parameter $(k) not found in model parameters.")
        end
    end

    init = copy(model.init)
    for (k, v) in init_vals
        if haskey(init, k)
            init[k] = v
        else
            error("Initial value $(k) not found in model initial values.")
        end
    end
    scen = Dynamic.DynamicParametrization(model.model, params, init, model.u0)

    sol = solve_model(scen)

    return sol
end

function compare_dynq_cases(
        cases;
        vars = [:AD, :AP, :AS],
        figure_size = (420 * length(cases), 360),
        legend_position = :rb,
        ylabel = "",
        sharey = false
    )
    f = Figure(size = figure_size)

    pretty = Dict(
        :AD => "Asset demand",
        :AP => "Asset price",
        :AS => "Asset supply",
        :SD => "Speculative debt",
        :AQ => "Asset amount",
        :Y => "Output",
        :D => "Debt financed demand",
        :ND => "Non-debt financed demand",
        :r => "Interest rate",
        :i => "Policy rate",
        :P => "Price level",
        :W => "Wage level",
        :N => "Employment",
        :U => "Unemployment rate"
    )

    axes = Axis[]

    for (idx, case) in enumerate(cases)
        ax = Axis(f[1, idx], title = case.label, ylabel = idx == 1 ? ylabel : "")
        push!(axes, ax)
        for v in vars
            lines!(ax, case.sol.paths[v], label = get(pretty, v, String(v)))
        end
        axislegend(ax, position = legend_position)
    end

    if sharey && !isempty(axes)
        ylims_all = [extrema(case.sol.paths[v]) for case in cases for v in vars]
        ymin = minimum(first, ylims_all)
        ymax = maximum(last, ylims_all)
        for ax in axes
            ylims!(ax, ymin, ymax)
        end
    end

    return f
end

function compare_dynq_real_cases(
        cases;
        figure_size = (420 * length(cases), 360),
        legend_position = :rb,
        ylabel = "Output",
        sharey = false
    )
    return compare_dynq_cases(
        cases;
        vars = [:Y, :D, :ND],
        figure_size = figure_size,
        legend_position = legend_position,
        ylabel = ylabel,
        sharey = sharey
    )
end


function create_gif(; model = Dynamic.DynQconAPLevelChange2, param_name = :s2, param_range = range(0.1, 0.9, length = 100), filename = "animation.gif", plotted_vars = [:AD, :AP, :AS], labels = ["Asset demand", "Asset price", "Asset supply"])
    sol_baseline = Dynamic.solve_model(model)
    xs = 1:length(sol_baseline.paths[:AD])

    obs = [Observable(sol_baseline.paths[v]) for v in plotted_vars]

    f = Figure()
    ax = Axis(f[1, 1])
    for (obs_var, label) in zip(obs, labels)
        lines!(ax, xs, obs_var, label = label)
    end
    axislegend(ax)
    


    record(f, filename, 1:length(param_range)) do i
        sol = run_dynq_case(model = model, overwrites = (param_name => param_range[i],))
        for (j, v) in enumerate(plotted_vars)
            obs[j][] = sol.paths[v]
        end
        ax.title = "$(param_name) = $(round(param_range[i], digits = 2))"
    end

    return f
end

function create_gif_init_vars(; model = Dynamic.DynQconAPLevelChange2, init_var_name = :AP, init_var_range = range(0.1, 0.9, length = 100), filename = "animation.gif", plotted_vars = [:AD, :AP, :AS], labels = ["Asset demand", "Asset price", "Asset supply"])
    sol_baseline = Dynamic.solve_model(model)
    xs = 1:length(sol_baseline.paths[:AD])

    obs = [Observable(sol_baseline.paths[v]) for v in plotted_vars]

    f = Figure()
    ax = Axis(f[1, 1])
    for (obs_var, label) in zip(obs, labels)
        lines!(ax, xs, obs_var, label = label)
    end
    axislegend(ax)
    


    record(f, filename, 1:length(init_var_range)) do i
        sol = run_dynq_case(model = model, init_vals = (init_var_name => [1.0, init_var_range[i]],))
        for (j, v) in enumerate(plotted_vars)
            obs[j][] = sol.paths[v]
        end
        ax.title = "$(init_var_name) = $(round(init_var_range[i], digits = 2))"
    end

    return f
end
end
