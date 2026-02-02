
"""
    display_sheets(sol::Solution; digits=3, compact=false, show_diff=true)

Nicely print balance sheets stored in `sol.sheets` using plain text (no PrettyTables).
"""
function display_sheets(sol::Solution; digits::Integer = 3, compact::Bool = false, show_diff::Bool = true)
    return display_sheets(sol.sheets; digits = digits, compact = compact, show_diff = show_diff)
end


function display_sheet(idx, sh; compact = true, digits = 3, show_diff = true)

    fmt(x) = isnan(x) ? "" : string(round(x; digits = digits))
    money(x) = round(x; digits = digits)
    assets = compact ? filter(p -> !iszero(p.second), sh.assets) : sh.assets
    liabs = compact ? filter(p -> !iszero(p.second), sh.liabilities) : sh.liabilities

    left_names = [String(p.first) for p in assets]
    right_names = [String(p.first) for p in liabs]

    left_vals = [fmt(p.second) for p in assets]
    right_vals = [fmt(p.second) for p in liabs]

    # widths
    lnw = maximum(vcat([length("Assets")], isempty(left_names) ? [0] : length.(left_names)))
    lvw = maximum(vcat([length("Value")], isempty(left_vals) ? [0] : length.(left_vals)))
    rnw = maximum(vcat([length("Liabilities")], isempty(right_names) ? [0] : length.(right_names)))
    rvw = maximum(vcat([length("Value")], isempty(right_vals) ? [0] : length.(right_vals)))

    n = max(length(assets), length(liabs))

    title = "Balance sheet $(idx): $(sh.sector_name)"
    println()
    println(title)
    println(repeat("─", length(title)))

    # header
    println(
        rpad("Assets", lnw), "  ", lpad("Value", lvw), "   │   ",
        rpad("Liabilities", rnw), "  ", lpad("Value", rvw)
    )
    println(
        repeat("─", lnw), "  ", repeat("─", lvw), "───┼───",
        repeat("─", rnw), "  ", repeat("─", rvw)
    )

    # rows
    for i in 1:n
        an = i <= length(left_names) ? left_names[i] : ""
        av = i <= length(left_vals) ? left_vals[i] : ""
        rn = i <= length(right_names) ? right_names[i] : ""
        rv = i <= length(right_vals) ? right_vals[i] : ""

        println(
            rpad(an, lnw), "  ", lpad(av, lvw), "   │   ",
            rpad(rn, rnw), "  ", lpad(rv, rvw)
        )
    end

    # totals
    total_assets = sum(p.second for p in assets)
    total_liabs = sum(p.second for p in liabs)
    diff = total_assets - total_liabs

    println(
        repeat("─", lnw), "  ", repeat("─", lvw), "───┼───",
        repeat("─", rnw), "  ", repeat("─", rvw)
    )
    println(
        rpad("TOTAL", lnw), "  ", lpad(fmt(total_assets), lvw), "   │   ",
        rpad("TOTAL", rnw), "  ", lpad(fmt(total_liabs), rvw)
    )

    return if show_diff
        println("Δ (assets - liabilities) = ", money(diff))
    end

end

"""
    display_sheets(sheets::Vector{BalanceSheetFilled}; digits=3, compact=false, show_diff=true)

Plain-text balance sheet printer.
"""
function display_sheets(
        sheets::Vector{BalanceSheetFilled};
        digits::Integer = 3,
        compact::Bool = false,
        show_diff::Bool = true,
    )
    isempty(sheets) && (println("No balance sheets."); return nothing)


    for (idx, sh) in enumerate(sheets)
        display_sheet(idx, sh, compact = compact, show_diff = show_diff, digits = digits)
    end

    return nothing
end

assets(sh::BalanceSheetFilled) = sum(p.second for p in sh.assets)
liabilities(sh::BalanceSheetFilled) = sum(p.second for p in sh.liabilities)

# Convenience totals for a solution (sum across all sheets)
assets(sol::Solution) = sum(assets(sh) for sh in sol.sheets)
liabilities(sol::Solution) = sum(liabilities(sh) for sh in sol.sheets)


function show(io::IO, sh::BalanceSheetFilled)
    digits = 3  # change if you want, or make it configurable via IOContext later

    assets = sh.assets
    liabs = sh.liabilities

    fmt(x) = isnan(x) ? "" : string(round(x; digits = digits))

    left_names = [String(p.first) for p in assets]
    right_names = [String(p.first) for p in liabs]
    left_vals = [fmt(p.second) for p in assets]
    right_vals = [fmt(p.second) for p in liabs]

    lnw = maximum(vcat([length("Assets")], isempty(left_names) ? [0] : length.(left_names)))
    lvw = maximum(vcat([length("Value")], isempty(left_vals) ? [0] : length.(left_vals)))
    rnw = maximum(vcat([length("Liabilities")], isempty(right_names) ? [0] : length.(right_names)))
    rvw = maximum(vcat([length("Value")], isempty(right_vals) ? [0] : length.(right_vals)))

    n = max(length(assets), length(liabs))

    title = "BalanceSheetFilled($(sh.sector_name))"
    println(io, title)
    println(io, repeat("─", length(title)))

    println(
        io,
        rpad("Assets", lnw), "  ", lpad("Value", lvw), "   │   ",
        rpad("Liabilities", rnw), "  ", lpad("Value", rvw)
    )
    println(
        io,
        repeat("─", lnw), "  ", repeat("─", lvw), "───┼───",
        repeat("─", rnw), "  ", repeat("─", rvw)
    )

    for i in 1:n
        an = i <= length(left_names) ? left_names[i] : ""
        av = i <= length(left_vals) ? left_vals[i] : ""
        rn = i <= length(right_names) ? right_names[i] : ""
        rv = i <= length(right_vals) ? right_vals[i] : ""
        println(io, rpad(an, lnw), "  ", lpad(av, lvw), "   │   ", rpad(rn, rnw), "  ", lpad(rv, rvw))
    end

    total_a = sum(p.second for p in assets)
    total_l = sum(p.second for p in liabs)

    println(
        io,
        repeat("─", lnw), "  ", repeat("─", lvw), "───┼───",
        repeat("─", rnw), "  ", repeat("─", rvw)
    )
    println(
        io,
        rpad("TOTAL", lnw), "  ", lpad(fmt(total_a), lvw), "   │   ",
        rpad("TOTAL", rnw), "  ", lpad(fmt(total_l), rvw)
    )

    diff = total_a - total_l
    return if abs(diff) > 10.0^(-digits)
        println(io, "Imbalance: ", round(diff; digits = digits))
    end
end

# Optional: nicer printing for a vector of sheets (REPL will use this)
function show(io::IO, sheets::Vector{BalanceSheetFilled})
    isempty(sheets) && return print(io, "BalanceSheetFilled[]")
    for (i, sh) in enumerate(sheets)
        i > 1 && println(io)  # blank line between sheets
        show(io, sh)
    end
    return
end
