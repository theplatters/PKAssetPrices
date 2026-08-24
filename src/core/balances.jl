struct BalanceSheet
    name::Symbol
    fields::Vector{Symbol}
    assets::Vector{Symbol}
    liabilities::Vector{Symbol}
    calculations::Dict{Symbol, Union{Symbol, Expr, Number}}
end

BalanceSheet(name::Symbol, fields::Vector{Symbol}, assets::Vector{Symbol},
             liabilities::Vector{Symbol}, calculations::AbstractDict) =
    BalanceSheet(name, fields, assets, liabilities,
        Dict{Symbol, Union{Symbol, Expr, Number}}(calculations))

struct BalanceSheetFilled
    sector_name::Symbol
    assets::Vector{Pair{Symbol, Float64}}
    liabilities::Vector{Pair{Symbol, Float64}}
end

Base.:(==)(a::BalanceSheetFilled, b::BalanceSheetFilled) =
    a.sector_name == b.sector_name && a.assets == b.assets && a.liabilities == b.liabilities

function parse_balance!(body)
    body isa Expr && body.head == :macrocall && length(body.args) == 4 ||
        error("Malformed @sheet block (source/offending expression: $body). Use `@sheet Name begin ... end`.")
    body.args[1] == Symbol("@sheet") || error("Expected @sheet, got source expression: $body")
    name, block = body.args[3], body.args[4]
    name isa Symbol || error("@sheet name must be a Symbol in source expression: $body")
    block isa Expr && block.head == :block ||
        error("@sheet $name must contain a begin...end block (offending expression: $body)")
    fields, assets, liabilities = Symbol[], Symbol[], Symbol[]
    calculations = Dict{Symbol, Union{Symbol, Expr, Number}}()
    for line in block.args
        line isa LineNumberNode && continue
        line isa Expr && line.head == :macrocall && length(line.args) == 3 ||
            error("Invalid @sheet entry (offending expression: $line). Use @asset or @liability with `name = expression`.")
        kind, assignment = line.args[1], line.args[3]
        kind in (Symbol("@asset"), Symbol("@liability")) ||
            error("Unknown @sheet entry $kind in expression $line. Use @asset or @liability.")
        assignment isa Expr && assignment.head == :(=) && length(assignment.args) == 2 ||
            error("Malformed asset/liability entry $line. Use `name = expression`.")
        field, rhs = assignment.args
        field isa Symbol || error("Asset/liability name must be a Symbol in expression: $line")
        field in fields && error("Duplicate balance-sheet field $field in sheet $name, offending expression `$line`. Rename or remove the duplicate field.")
        rhs isa Union{Expr, Symbol, Number} ||
            error("Asset/liability value must be an expression, Symbol, or number in expression: $line")
        push!(fields, field)
        kind == Symbol("@asset") ? push!(assets, field) : push!(liabilities, field)
        calculations[field] = rhs
    end
    return BalanceSheet(name, fields, assets, liabilities, calculations)
end

function parse_balances!(out, body)
    body isa Expr && body.head == :block ||
        error("Expected a begin...end block for @balances (offending expression: $body).")
    for line in body.args
        line isa LineNumberNode && continue
        line isa Expr && line.head == :macrocall && length(line.args) == 4 &&
            line.args[1] == Symbol("@sheet") ||
            error("Invalid @balances entry (offending expression: $line). Use @sheet blocks.")
        sheet = parse_balance!(line)
        any(existing -> existing.name == sheet.name, out) &&
            error("Duplicate @sheet name $(sheet.name) in source/offending expression `$line`; " *
                "remove or rename the duplicate sector before accounting can be evaluated.")
        push!(out, sheet)
    end
    return out
end

"Validate sheet symbols and return calculations in dependency order."
function _sheet_order(sheets, allowed, source)
    order = Tuple{BalanceSheet, Symbol, Any}[]
    for sheet in sheets
        local_names = Set(sheet.fields)
        for name in sheet.fields
            rhs = sheet.calculations[name]
            found = _free_rhs_symbols!(Set{Symbol}(), rhs)
            unknown = sort!(collect(setdiff(found, union(Set(allowed), _MODEL_MATH_NAMES, local_names))))
            isempty(unknown) || error("$source: unknown balance-sheet symbol $(first(unknown)) in sheet $(sheet.name), calculation $name, expression `$rhs`. Declare it as a variable/parameter, or fix the symbol.")
        end
        # Dependencies are deliberately per sheet: fields in one sheet may
        # depend only on fields in that same sheet (cross-sheet references are
        # not supported).
        pending = copy(sheet.fields); done = Set{Symbol}()
        while !isempty(pending)
            progress = false
            for name in copy(pending)
                deps = intersect(_free_rhs_symbols!(Set{Symbol}(), sheet.calculations[name]), local_names)
                if isempty(setdiff(deps, done))
                    push!(order, (sheet, name, sheet.calculations[name])); push!(done, name)
                    deleteat!(pending, findfirst(==(name), pending)); progress = true
                end
            end
            progress || error("$source: cyclic balance-sheet calculations in sheet $(sheet.name): $(join(string.(pending), ", ")). Rewrite the expressions to remove the cycle.")
        end
    end
    return order
end

function generate_sheet_eval(sheets, variables, parameters; lag_symbols=Symbol[], source="model")
    allowed = vcat(Symbol[variables...], Symbol[parameters...], Symbol[lag_symbols...])
    order = _sheet_order(sheets, allowed, source)
    destructure = unique(vcat(Symbol[parameters...], Symbol[lag_symbols...], Symbol[variables...]))
    bs_type = GlobalRef(@__MODULE__, :BalanceSheetFilled)
    sheet_outputs = Any[]
    for sheet in sheets
        sheet_order = [(name, rhs) for (s, name, rhs) in order if s === sheet]
        assigns = Any[:($(name) = Float64($(rhs)) ) for (name, rhs) in sheet_order]
        aa = [:( $(QuoteNode(a)) => Float64($(a)) ) for a in sheet.assets]
        ll = [:( $(QuoteNode(l)) => Float64($(l)) ) for l in sheet.liabilities]
        push!(sheet_outputs, :(let
            $(assigns...)
            $(bs_type)[$(bs_type)($(QuoteNode(sheet.name)), Pair{Symbol,Float64}[$(aa...)], Pair{Symbol,Float64}[$(ll...)])]
        end))
    end
    return quote
        function (context)
            (; $(destructure...)) = context
            result = $(bs_type)[]
            $( [:(append!(result, $expr)) for expr in sheet_outputs]... )
            return result
        end
    end
end

"""Check sector-level and aggregate balance-sheet identities.

Use `Static.check_accounting(sol)` or `Dynamic.check_accounting(sol)` for
public solution-level checks.
"""
function _accounting_result(sheets; tol=1e-8, strict=false, period=nothing)
    tol isa Real && tol >= 0 || error("check_accounting: tol must be a nonnegative real number (got $tol).")
    seen = Set{Symbol}()
    duplicates = Symbol[]
    for sheet in sheets
        sheet.sector_name in seen && push!(duplicates, sheet.sector_name)
        push!(seen, sheet.sector_name)
    end
    isempty(duplicates) || error("check_accounting: duplicate BalanceSheetFilled sector_name(s) " *
        "$(join(string.(unique(duplicates)), ", "))" *
        "; each sector must appear exactly once (period=$(period)); fix the offending sheets.")
    deltas = Dict{Symbol, Float64}(s.sector_name => sum(p.second for p in s.assets) - sum(p.second for p in s.liabilities) for s in sheets)
    aggregate = sum(values(deltas))
    consistent = all(abs(v) <= tol for v in values(deltas)) && abs(aggregate) <= tol
    if !consistent
        msg = "Accounting inconsistency" * (isnothing(period) ? "" : " at period $period") *
            ": " * join(["$k => $v" for (k,v) in deltas if abs(v) > tol], ", ") * "; aggregate => $aggregate"
        strict ? error(msg) : @warn msg
    end
    return (consistent=consistent, sector_deltas=deltas, aggregate=aggregate)
end
