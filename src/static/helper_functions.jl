@inline pad_to(v, n, x) = length(v) >= n ? v : vcat(v, fill(x, n - length(v)))

function show(io::IO, m::Model{F, C}) where {F <: Function, C <: Function}
    payload = displaysize(io)[2] >= 80 ?
        [["$var: $(m.variable_descriptions[var])" for var in m.variables], ["$parameter: $(m.parameter_descriptions[parameter])" for parameter in m.parameters], string.(m.equations)] :
        [m.variables, m.parameters, string.(m.equations)]
    column_labels = [["Variables", "Parameters", "Equations"], "Amount: " .* string.(length.([m.variables, m.parameters, m.equations]))]
    max_len = length.([m.variables, m.parameters, m.equations]) |> maximum
    data = reduce(
        hcat,
        pad_to.(payload, max_len, "")
    )

    show(
        io, pretty_table(
            data;
            title = "Model",
            column_labels = column_labels,
            fit_table_in_display_vertically = false,
            fit_table_in_display_horizontally = false
        )
    )
    return nothing
end

function show(io::IO, ::MIME"text/plain", m::Model{F, C}) where {F <: Function, C <: Function}
    return show(io, m)
end


function show(io::IO, p::Parametrization{F, C}) where {F <: Function, C <: Function}
    if get(io, :compact, false)
        return print(
            io, "Parametrization(", length(p.params), " params, u0[",
            length(p.u0), "])"
        )
    end

    m = p.model

    println(io, "Parametrization")
    println(io, "───────────────")
    println(
        io, "Model:      ", length(m.variables), " vars, ",
        length(m.parameters), " params, ",
        length(m.equations), " eqs, ",
        length(m.curves), " curves, ",
        length(m.balance_sheets), " sheets"
    )
    println(io, "Params:     ", length(p.params), " set / ", length(m.parameters), " declared")
    println(io, "u0 length:  ", length(p.u0))

    # Display params in declared order (then extras), aligned
    declared = m.parameters
    extra = [k for k in keys(p.params) if !(k in declared)]
    ordered = vcat(declared, sort(extra; by = string))

    shown = [(k, p.params[k]) for k in ordered if haskey(p.params, k)]
    if !isempty(shown)
        namew = maximum(length.(string.(first.(shown))))
        println(io)
        println(io, "Parameters")
        println(io, "──────────")
        for (k, v) in shown
            println(io, rpad(string(k), namew), " = ", v)
        end
    end

    # Warn about missing declared params
    missing = [k for k in declared if !haskey(p.params, k)]
    if !isempty(missing)
        println(io)
        println(io, "Missing declared params: ", join(string.(missing), ", "))
    end

    return nothing
end

function show(io::IO, ::MIME"text/plain", p::Parametrization{F, C}) where {F <: Function, C <: Function}
    return show(io, p)
end


# helper for BalanceSheetFilled
_sheet_name(s::BalanceSheetFilled) = s.sector_name

function show(io::IO, sol::Solution{F, C}) where {F <: Function, C <: Function}
    if get(io, :compact, false)
        return print(
            io, "Solution(", length(sol.variables), " vars, ",
            length(sol.sheets), " sheets)"
        )
    end

    p = sol.model
    m = p.model

    println(io, "Solution")
    println(io, "────────")
    println(io, "Variables:      ", length(sol.variables), " values")
    println(io, "Sheets:         ", length(sol.sheets))
    println(
        io, "Model:          ", length(m.variables), " vars, ",
        length(m.parameters), " params, ",
        length(m.equations), " eqs"
    )

    # Print variables in model order where possible, then extras
    declared = m.variables
    extra = [k for k in keys(sol.variables) if !(k in declared)]
    ordered = vcat(declared, sort(extra; by = string))

    shown = [(k, sol.variables[k]) for k in ordered if haskey(sol.variables, k)]
    if !isempty(shown)
        namew = maximum(length.(string.(first.(shown))))
        println(io)
        println(io, "Variable values")
        println(io, "───────────────")
        for (k, v) in shown
            println(io, rpad(string(k), namew), " = ", v)
        end
    end

    # Summarize balance sheets (sector + counts)
    if !isempty(sol.sheets)
        println(io)
        println(io, "Balance sheets")
        println(io, "──────────────")
        for (i, s) in enumerate(sol.sheets)
            println(
                io,
                lpad(i, 3), ": ",
                _sheet_name(s),
                " (assets=", length(s.assets),
                ", liabilities=", length(s.liabilities), ")"
            )
        end
    end

    return nothing
end

function show(io::IO, ::MIME"text/plain", sol::Solution{F, C}) where {F <: Function, C <: Function}
    return show(io, sol)
end

function Base.getproperty(m::Solution{F, C}, x::Symbol) where {F <: Function, C <: Function}
    if haskey(getfield(m, :(variables)), x)
        return m.variables[x]
    end
    return getfield(m, x)
end

# "central_bank_credit" -> "Central Bank Credit"
function title_from_snake(s::AbstractString)
    words = split(s, '_'; keepempty = false)
    cap1(w) = isempty(w) ? w : uppercasefirst(lowercase(w))
    return join(cap1.(words), ' ')
end

# "central_bank_credit" -> "Central Bank Credit"
title_from_snake(s::Symbol) = title_from_snake(string(s))

function to_html(b::BalanceSheetFilled)
    header = """
    <div style="border: 1px solid #ddd; padding: 9px;">
    <h3> Sector: $(b.sector_name) </h3>
    <table>
      <thead  style="border-bottom: 2px solid #ddd">
      <tr>
        <th>Assets </th>
        <th> Value </th>
        <th>Liabilities </th>
        <th> Value </th>
      </tr>
      </thead>
    """

    body = "<tbody>"
    for i in 1:max(length(b.assets), length(b.liabilities))
        asset = i <= length(b.assets) ? b.assets[i] : nothing
        liability = i <= length(b.liabilities) ? b.liabilities[i] : nothing
        asset_name = isnothing(asset) ? "" : title_from_snake(asset[1])
        asset_value = isnothing(asset) ? "" : round(asset[2], digits = 2)
        liability_name = isnothing(liability) ? "" : title_from_snake(liability[1])
        liability_value = isnothing(liability) ? "" : round(liability[2], digits = 2)
        body *= """
          <tr>
            <td> $asset_name</td>
            <td> $asset_value </td>
            <td> $liability_name</td>
            <td> $liability_value </td>
          </tr>
        """
    end

    body *= "</tbody>"

    footer = """
    <tfoot style="border-top: 2px solid #ddd">
          <tr>
            <td> Total</td>
            <td> $(round(assets(b), digits = 2))</td>
            <td> Total</td>
            <td> $(round(liabilities(b), digits = 2))</td>
          </tr>
    </tfoot>
    </table>
    </div>
    """


    return header * body * footer
end


function Base.show(io::IO, ::MIME"text/html", x::BalanceSheetFilled)
    println(io, to_html(x))
    return nothing
end


function Base.show(io::IO, ::MIME"text/html", x::Vector{BalanceSheetFilled})
    tables = join(to_html.(x), "\n")  # each to_html already returns a <table> block

    html = """
    <div style="
        display:flex;
        flex-wrap:wrap;
        gap:16px;
        align-items:flex-start;
    ">
      $tables
    </div>
    """

    print(io, html)
    return nothing
end

function build_table_from_solutions(solutions, scenario_names = ["Baseline", "Exogenous Alpha", "Central Bank Sense", "Dual Interest", "ExoAlpha + Dual Interest"])
    table = "<table><tr><th>Variable</th>"
    for (i, solution) in enumerate(solutions)
        table *= "<th>Scenario $i: $(scenario_names[i])</th>"
    end
    table *= "</tr>"

    variables = solutions[1].model.model.variables

    for var in variables
        table *= "<tr><td>$var</td>"
        for solution in solutions
            value = getproperty(solution, var)
            table *= "<td>$value</td>"
        end
        table *= "</tr>"
    end

    table *= "</table>"
    return Base.HTML{String}(table)
end

function eval_curve(param::Parametrization, input::Dict{Symbol, Float64})
    return param.model.curve_eval(input, param.params)
end

function eval_curve(sol::Solution)
    return sol.model.model.curve_eval(sol.variables, sol.model.params)
end

function eval_curve(sol::Solution, variable, iter_range, curve)
    evaluated = Float64[]
    vars = copy(sol.variables)
    for item in iter_range
        vars[variable] = item
        push!(evaluated, sol.model.model.curve_eval(vars, sol.model.params)[curve])
    end
    return evaluated
end


function bar_chart(sols::AbstractDict{String, <:Solution}, variables::Vector{Symbol})
    colors = Makie.wong_colors()
    sol_values = (
        key => [getproperty(sol, variable) / getproperty(first(values(sols)), variable) for variable in variables] for (key, sol) in sols
    )
    labels = map(first, sol_values)
    value_raw = map(last, sol_values) |> Base.Fix1(reduce, vcat)

    bar_positions = reduce(vcat, [fill(0, length(variables)) .+ i for i in 1:length(labels)])


    fig = Figure()
    ax = Axis(fig[1, 1], xticks = (1:length(labels), labels))
    grouping = repeat(1:length(variables), length(labels))
    barplot!(ax, bar_positions, value_raw, dodge = grouping, color = [colors[i] for i in grouping])

    elements = [PolyElement(color = colors[i]) for i in 1:length(variables)]
    title = "Groups"

    Legend(fig[1, 2], elements, String.(variables), title)

    return fig
end

function is_ir_component(solution::Static.Solution)
    output_range = range(0.0, 15.0; length = 200)
    rate_range = range(0.0, 0.20; length = 200)

    is_values = Float64[]
    for r in rate_range
        vars = copy(solution.variables)
        vars[:r] = r
        curves = Static.eval_curve(solution.model, vars)
        push!(is_values, curves.IS)
    end

    ir_r_values = Float64[]
    for y in output_range
        vars = copy(solution.variables)
        vars[:Y] = y
        curves = Static.eval_curve(solution.model, vars)
        push!(ir_r_values, curves.IR)
    end

    fig = Figure(size = (800, 480))
    ax = Axis(
        fig[1, 1];
        title = "IS – IR Curves",
        xlabel = "Output (Y)",
        ylabel = "Interest rate (r)",
        backgroundcolor = :white,
    )

    lines!(ax, is_values, collect(rate_range); color = :royalblue, linewidth = 3, label = "IS")
    lines!(ax, collect(output_range), ir_r_values; color = :crimson, linewidth = 3, label = "IR")
    xlims!(ax, 0.0, 15.0)
    ylims!(ax, 0.0, 0.20)

    axislegend(ax; position = :rt, framevisible = false)

    return fig
end
function ad_as_component(solution::Static.Solution)

    AP_eq = solution.variables[:AP]
    AS_eq = solution.variables[:AS]
    AD_eq = solution.variables[:AD]

    AP_min = AP_eq * 0.2
    AP_max = AP_eq * 3.0
    AP_range = range(AP_min, AP_max; length = 200)

    ad_values = Float64[]
    as_values = Float64[]
    for AP in AP_range
        vars = copy(solution.variables)
        vars[:AP] = AP
        curves = Static.eval_curve(solution.model, vars)
        push!(ad_values, curves.AMD)
        push!(as_values, curves.AMS)
    end

    fig = Figure(size = (800, 480))
    ax = Axis(
        fig[1, 1];
        title = "AmS – AmD Curves",
        xlabel = "Quantity",
        ylabel = "Asset price (AP)",
        backgroundcolor = :white,
    )

    lines!(ax, ad_values, collect(AP_range); color = :royalblue, linewidth = 3, label = "AmD")
    lines!(ax, as_values, collect(AP_range); color = :crimson, linewidth = 3, label = "AmS")
    scatter!(
        ax, [AD_eq / AP_eq], [AP_eq];
        color = :black,
        markersize = 14,
        strokecolor = :white,
        strokewidth = 2,
        label = "Equilibrium",
    )

    axislegend(ax; position = :rt, framevisible = false)

    return fig
end

function ad_as_comparison_component(
        solutions::AbstractVector{<:Static.Solution},
        labels::AbstractVector{<:AbstractString},
    )
    fig = Figure(size = (800, 480))
    ax = Axis(
        fig[1, 1];
        title = "AmS – AmD Curves Comparison",
        xlabel = "Quantity",
        ylabel = "Asset price (AP)",
        backgroundcolor = :white,
    )

    colors = Makie.wong_colors()

    for (i, (solution, label)) in enumerate(zip(solutions, labels))
        AP_eq = solution.variables[:AP]
        AS_eq = solution.variables[:AS]
        AD_eq = solution.variables[:AD]

        AP_range = range(AP_eq * 0.2, AP_eq * 3.0; length = 200)

        ad_values = Float64[]
        as_values = Float64[]
        for AP in AP_range
            vars = copy(solution.variables)
            vars[:AP] = AP
            curves = Static.eval_curve(solution.model, vars)
            push!(ad_values, curves.AMD)
            push!(as_values, curves.AMS)
        end

        color = colors[mod1(i, length(colors))]

        lines!(
            ax, ad_values, collect(AP_range);
            color = color,
            linewidth = 3,
            label = "AmD – $label",
        )
        lines!(
            ax, as_values, collect(AP_range);
            color = color,
            linewidth = 3,
            linestyle = :dash,
            label = "AmS – $label",
        )
        scatter!(
            ax, [AD_eq / AP_eq], [AP_eq];
            color = color,
            markersize = 14,
            strokecolor = :white,
            strokewidth = 2,
            label = "Eq. – $label",
        )
    end

    axislegend(ax; position = :rt, framevisible = false)

    return fig
end
