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
