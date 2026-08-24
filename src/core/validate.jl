const _MODEL_MATH_NAMES = Set{Symbol}([
    :+, :-, :*, :/, :^,
    :sqrt, :exp, :log, :abs, :min, :max,
    :pi, :π, :ℯ, :Inf, :NaN,
])

function _validation_error(label, message)
    error("$label: $message")
end

function _free_rhs_symbols!(found::Set{Symbol}, ex, bound=Set{Symbol}())
    if ex isa Symbol
        ex in bound || push!(found, ex)
    elseif ex isa Expr
        if ex.head == :call
            isempty(ex.args) && return
            head = ex.args[1]
            head isa Symbol && push!(found, head)
            for arg in ex.args[2:end]
                _free_rhs_symbols!(found, arg, bound)
            end
        elseif ex.head == :let
            local_bound = copy(bound)
            binding_spec, body = ex.args[1], ex.args[end]
            if binding_spec isa Expr && binding_spec.head == :(=)
                _free_let_binding!(found, local_bound, binding_spec)
            elseif binding_spec isa Expr && binding_spec.head == :block &&
                    !isempty(binding_spec.args)
                for part in binding_spec.args
                    part isa LineNumberNode && continue
                    _free_let_binding!(found, local_bound, part)
                end
            elseif binding_spec isa Expr && binding_spec.head == :block &&
                    body isa Expr && body.head == :block
                _free_let_body!(found, local_bound, body)
                return found
            else
                _free_rhs_symbols!(found, binding_spec, local_bound)
            end
            body isa Expr && body.head == :block ?
                _free_let_body!(found, local_bound, body) :
                _free_rhs_symbols!(found, body, local_bound)
        elseif ex.head == :ref
            # A non-rewritten reference can still occur for a non-stock value;
            # its index is syntax, not a model variable.
            !isempty(ex.args) && _free_rhs_symbols!(found, ex.args[1], bound)
        else
            for arg in ex.args
                _free_rhs_symbols!(found, arg, bound)
            end
        end
    end
    return found
end

function _free_let_body!(found::Set{Symbol}, bound::Set{Symbol}, body::Expr)
    for part in body.args
        part isa LineNumberNode && continue
        if part isa Expr && part.head == :(=)
            _free_let_binding!(found, bound, part)
        else
            _free_rhs_symbols!(found, part, bound)
        end
    end
    return found
end

function _free_let_binding!(found::Set{Symbol}, bound::Set{Symbol}, binding)
    binding isa Expr && binding.head == :(=) && length(binding.args) == 2 ||
        return _free_rhs_symbols!(found, binding, bound)
    _free_rhs_symbols!(found, binding.args[2], bound)
    binding.args[1] isa Symbol && push!(bound, binding.args[1])
    return found
end

function _reject_static_refs!(label, ex, equation)
    ex isa Expr || return
    ex.head == :ref && error(
        "$label: indexed reference $(ex) is not allowed in a static equation RHS " *
        "($(equation)). Use a declared symbol instead.")
    for arg in ex.args
        _reject_static_refs!(label, arg, equation)
    end
end

"Validate the structural and symbol-level invariants of a model definition."
function validate_model(face::Symbol, source, variable_names, parameter_names,
                        equations::Vector{Equation})
    label = "$face @model at $(source)"
    vars = Symbol[variable_names...]
    params = Symbol[parameter_names...]

    duplicate_vars = unique(v for v in vars if count(==(v), vars) > 1)
    isempty(duplicate_vars) || _validation_error(
        label, "duplicate variable declaration(s): $(join(duplicate_vars, ", ")). " *
        "Declare each variable once.")

    duplicate_params = unique(p for p in params if count(==(p), params) > 1)
    isempty(duplicate_params) || _validation_error(
        label, "duplicate parameter declaration(s): $(join(duplicate_params, ", ")). " *
        "Declare each parameter once.")

    collisions = intersect(Set(vars), Set(params))
    isempty(collisions) || _validation_error(
        label, "variable/parameter name collision(s): $(join(sort!(collect(collisions)), ", ")). " *
        "Rename the variable or parameter.")

    lhs_names = Symbol[]
    for eq in equations
        if eq.lhs isa Symbol
            push!(lhs_names, eq.lhs)
        elseif face === :dynamic && eq.lhs isa Expr && eq.lhs.head == :ref &&
                length(eq.lhs.args) >= 1 && eq.lhs.args[1] isa Symbol
            # This is retained for an undeclared dynamic reference that the
            # time rewrite could not recognize as a declared stock.
            push!(lhs_names, eq.lhs.args[1])
        else
            _validation_error(
                label, "equation LHS must be a declared variable, got $(eq.lhs). " *
                "Put a declared variable on the left-hand side.")
        end
    end

    duplicate_lhs = unique(v for v in lhs_names if count(==(v), lhs_names) > 1)
    missing_lhs = [v for v in vars if !(v in lhs_names)]
    undeclared_lhs = unique(v for v in lhs_names if !(v in vars))
    if !isempty(missing_lhs) || !isempty(duplicate_lhs) || !isempty(undeclared_lhs)
        structural = String[
            "missing equation LHS: " * (isempty(missing_lhs) ? "none" : join(missing_lhs, ", ")),
            "duplicate equation LHS: " * (isempty(duplicate_lhs) ? "none" : join(duplicate_lhs, ", ")),
        ]
        !isempty(undeclared_lhs) && push!(
            structural, "undeclared equation LHS: " * join(undeclared_lhs, ", "))
        push!(structural, "Add one equation for each declared variable, remove duplicate equations, " *
            "and declare or rename every LHS.")
        _validation_error(label, join(structural, "; "))
    end

    declared = union(Set(vars), Set(params))
    for (index, eq) in enumerate(equations)
        face === :static && _reject_static_refs!(label, eq.rhs, eq)
        found = Set{Symbol}()
        _free_rhs_symbols!(found, eq.rhs)
        # Synthetic lag names are produced by the dynamic rewrite and are
        # valid when their base variable was declared.
        allowed_lags = Set(Symbol(v, "[t - ", lag, "]") for v in vars for lag in (1, 2))
        unknown = sort!(collect(setdiff(found, union(declared, _MODEL_MATH_NAMES, allowed_lags))))
        isempty(unknown) || _validation_error(
            label, "unknown symbol(s) in equation $index (`$(eq)`): $(join(unknown, ", ")). " *
            "Declare the symbol, or fix the typo in this equation.")
    end
    return nothing
end
