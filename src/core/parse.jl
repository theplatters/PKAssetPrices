"""Strictly walk entries in one of the shared model DSL blocks."""
function _walk_entries(body, kind::Symbol; stringify_description=false)
    entries = Tuple{Any, Any}[]
    body isa Expr && body.head == :block ||
        error("Expected a begin...end block for @$kind, got: $body")
    for line in body.args
        line isa LineNumberNode && continue
        if kind === :variables
            if line isa Symbol
                push!(entries, (line, ""))
            elseif line isa Expr && line.head == :(=)
                length(line.args) == 2 || error("Invalid variable entry: $line")
                lhs, rhs = line.args
                lhs isa Symbol || error("Variable name must be a Symbol in: $line")
                rhs isa String || error("Variable description must be a String in: $line")
                desc = stringify_description ? String(rhs) : rhs
                push!(entries, (lhs, desc))
            else
                error("Invalid variable entry (expected `name` or `name = \"description\"`): $line")
            end
        elseif kind === :parameters
            if line isa Expr && line.head == :(=)
                length(line.args) == 2 || error("Invalid parameter entry: $line")
                lhs, rhs = line.args
                lhs isa Symbol || error("Parameter name must be a Symbol in: $line")
                if rhs isa Expr && rhs.head == :tuple
                    length(rhs.args) == 2 || error("Parameter descriptions require `value, \"description\"` in: $line")
                    rhs.args[2] isa String || error("Parameter description must be a String in: $line")
                    desc = stringify_description ? String(rhs.args[2]) : rhs.args[2]
                    push!(entries, (lhs, (rhs.args[1], desc)))
                else
                    push!(entries, (lhs, (rhs, "")))
                end
            else
                error("Invalid parameter entry (expected `name = value`): $line")
            end
        elseif kind === :equations
            if line isa Expr && line.head == :call && length(line.args) == 3 && line.args[1] == :(==)
                push!(entries, (line.args[2], line.args[3]))
            else
                error("@equations entries must be `lhs == rhs`, got: $line")
            end
        end
    end
    return entries
end

parse_variable_entries(body; kwargs...) = _walk_entries(body, :variables; kwargs...)
parse_parameter_entries(body; kwargs...) = _walk_entries(body, :parameters; kwargs...)
parse_equation_entries(body; kwargs...) = _walk_entries(body, :equations; kwargs...)

"""Parse shock entries while retaining literal ASTs for later macro code.
Returns named tuples `(param, from, until, value, source)`."""
function parse_shock_entries(body)
    forms = "at(period, param = value[, param2 = value2, ...]) and " *
        "during(first:last, param = value[, param2 = value2, ...])"
    body isa Expr && body.head == :block || error("Expected a begin...end block for @shocks, got source/offending expression: $body. Expected forms: $forms")
    entries = NamedTuple{(:param, :from, :until, :value, :source), Tuple{Symbol,Any,Any,Any,String}}[]
    for line in body.args
        line isa LineNumberNode && continue
        line isa Expr && line.head == :call && !isempty(line.args) || error("Invalid @shocks entry/source expression `$line`; expected forms: $forms")
        kind = line.args[1]
        kind in (:at, :during) || error("Invalid @shocks entry/source expression `$line`; expected forms: $forms")
        length(line.args) >= 2 || error("Invalid @shocks entry/source expression `$line`; expected forms: $forms")
        firstarg = line.args[2]
        from, until = if kind === :at
            _shock_literal(firstarg, line, forms); (firstarg, nothing)
        else
            firstarg isa Expr && firstarg.head == :call && length(firstarg.args) == 3 && string(firstarg.args[1]) == ":" || error("Invalid @shocks entry/source expression `$line`: during requires `first:last`; expected forms: $forms")
            _shock_literal(firstarg.args[2], line, forms); _shock_literal(firstarg.args[3], line, forms)
            _shock_literal_value(firstarg.args[2]) <= _shock_literal_value(firstarg.args[3]) || error("Invalid @shocks entry/source expression `$line`: first must be <= last; expected forms: $forms")
            (firstarg.args[2], firstarg.args[3])
        end
        length(line.args) >= 3 || error("Invalid @shocks entry/source expression `$line`: empty kwargs; expected forms: $forms")
        for kw in line.args[3:end]
            kw isa Expr && kw.head == :kw && length(kw.args) == 2 && kw.args[1] isa Symbol || error("Invalid @shocks entry/source expression `$line`: every assignment must be `param = value` (not positional or ==); expected forms: $forms")
            _shock_literal(kw.args[2], line, forms)
            push!(entries, (param=kw.args[1], from=from, until=until, value=kw.args[2], source=string(line)))
        end
    end
    return entries
end
function _shock_literal(ex, line, forms)
    candidate = ex
    if ex isa Expr && ex.head == :call && length(ex.args) == 2 && ex.args[1] in (:+, :-)
        ex.args[2] isa Bool && error("Invalid @shocks entry/source expression `$line`: unary $(ex.args[1]) cannot be applied to Bool; expected a finite real literal; expected forms: $forms")
        ex.args[2] isa Real || error("Invalid @shocks entry/source expression `$line`: expected a finite real literal; expected forms: $forms")
        candidate = ex.args[1] === :- ? -ex.args[2] : ex.args[2]
    end
    candidate isa Real && !(candidate isa Bool) && isfinite(candidate) || error("Invalid @shocks entry/source expression `$line`: expected a finite real literal (not Bool); expected forms: $forms")
end
_shock_literal_value(ex) = ex isa Real ? ex : (ex.args[1] === :- ? -ex.args[2] : ex.args[2])

function parse_scenario_entries(body)
    body isa Expr && body.head == :block ||
        error("Expected a begin...end block for @scenario, got: $body")
    entries = Pair{Symbol, Any}[]
    names = Symbol[]
    for line in body.args
        line isa LineNumberNode && continue
        line isa Expr && line.head == :(=) && length(line.args) == 2 ||
            error("@scenario entries must be `parameter = value`, got: $line")
        name, value = line.args
        name isa Symbol || error("@scenario parameter name must be a Symbol in: $line")
        name in names && error("Duplicate @scenario parameter: $name. Set each parameter once.")
        push!(names, name)
        push!(entries, name => value)
    end
    return entries
end

"Parse the dynamic scenario grammar, leaving block contents unevaluated."
function parse_dynamic_scenario_entries(body)
    body isa Expr && body.head == :block ||
        error("Expected a begin...end block for @scenario, got: $body")
    params = Pair{Symbol, Any}[]
    names = Set{Symbol}()
    equations = nothing
    init = nothing
    shocks = nothing
    for line in body.args
        line isa LineNumberNode && continue
        if line isa Expr && line.head == :(=) && length(line.args) == 2
            name = line.args[1]
            name isa Symbol || error("@scenario parameter name must be a Symbol in source expression: $line")
            name in names && error("Duplicate @scenario parameter $name in source expression `$line`. Set each parameter once.")
            push!(names, name); push!(params, name => line.args[2])
        elseif line isa Expr && line.head == :macrocall && length(line.args) == 3
            block_name, block = line.args[1], line.args[3]
            block_name == Symbol("@equations") && isnothing(equations) && (equations = block; continue)
            block_name == Symbol("@init") && isnothing(init) && (init = block; continue)
            block_name == Symbol("@shocks") && isnothing(shocks) && (shocks = block; continue)
            if block_name in (Symbol("@equations"), Symbol("@init"), Symbol("@shocks"))
                error("Duplicate dynamic @scenario block $block_name in source/offending expression `$line`; remove the duplicate block.")
            end
            error("Unknown dynamic @scenario block $block_name in source/offending expression `$line`; valid blocks are @equations, @init, and @shocks.")
        else
            error("Dynamic @scenario entries must be parameter assignments or @equations/@init/@shocks blocks, got source/offending expression: $line")
        end
    end
    return params, equations, init, shocks
end
