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

# "central_bank_credit" -> "Central Bank Credit"
function title_from_snake(s::AbstractString)
    words = split(s, '_'; keepempty = false)
    cap1(w) = isempty(w) ? w : uppercasefirst(lowercase(w))
    return join(cap1.(words), ' ')
end

# "central_bank_credit" -> "Central Bank Credit"
title_from_snake(s::Symbol) = title_from_snake(string(s))
