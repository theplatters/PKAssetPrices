using Optimization, OptimizationIpopt, OptimizationOptimJL
using SciMLSensitivity
using ForwardDiff
using PKAssetPrices
using StatsBase
using LinearAlgebra

function positivity_penalty(paths)
    return sum(max(0, -xi)^2 for xi in reduce(vcat, values(paths)))
end

function objective(x, p)
    model = Dynamic.update_params(p, x)


    sol = Dynamic.solve_model(model)

    return score(sol.paths)
end

score(paths) = - oscillation_score(paths[:Y]) + positivity_penalty(paths) + explosion_penalty(paths)


function eval_model(x, p)
    model = Dynamic.update_params(p, x)

    sol = Dynamic.solve_model(model)

    return sol
end

function explosion_penalty(y)
    return sum(max(0, abs(xi) - 1000)^2 for xi in reduce(vcat, values(y)))
end

function oscillation_score(y)
    # Penalty for negative values
    x = y[50:end]

    μ = mean(x)

    # Zero-crossings (crossing the mean)
    crossings = sum(diff(x .> μ) .!= 0)
    # Sign changes in differences
    dx = diff(x)
    signs = sign.(dx)
    sign_changes = sum(abs.(diff(signs)) .> 0)

    return crossings + sign_changes
end


x0 = [0.8, 0.1, 0.01, 0.05, 0.01, 0.99, 0.1, 0.2, 0.5, 0.1, 5.0, 8.0, 0.3, 0.15]


function callback(state, loss)
    println("Iteration: $(state.iter), Loss: $loss, Params: $(state.u)")
    return false  # return true to stop optimization
end

p = (
    model = Dynamic.DynαQCr
)

lb = fill(0.0, 14)
ub = [fill(1.0, 10); 12.0; 12.0; 1.0; 0.4]
optf = OptimizationFunction(objective, ADTypes.AutoZygote())
prob = OptimizationProblem(
    optf, x0, p,
    lb = lb,
    ub = ub
)
sol = solve(prob, IpoptOptimizer(), callback = callback)
@info sol

function debug_gradient(x, p)
    """Test gradient computation"""
    println("\n" * "="^60)
    println("DEBUG: Gradient Analysis")
    println("="^60)

    try
        grad = ForwardDiff.gradient(x -> objective(x, p), x)

        if grad === nothing
            println("✗ Gradient is nothing")
            return nothing
        end

        nan_count = sum(isnan.(grad))
        inf_count = sum(isinf.(grad))

        println("Gradient norm: $(norm(grad))")
        println("NaN count: $nan_count")
        println("Inf count: $inf_count")
        println("Gradient: $(grad)")

        if nan_count > 0 || inf_count > 0
            println("✗ Gradient contains invalid values!")
            for (i, g) in enumerate(grad)
                if !isfinite(g)
                    println("  Parameter $i (x[$i] = $(x[i])): gradient = $g")
                end
            end
        else
            println("✓ Gradient is clean")
        end

        return grad
    catch e
        println("✗ Gradient computation failed: $e")
        println("Stacktrace:")
        showerror(stdout, e, catch_backtrace())
        return nothing
    end
end

debug_gradient(x0, Dynamic.DynαQCr)


function debug_gradient_detailed(x, p)
    """Pinpoint exactly where NaN enters the computation"""
    println("\n" * "="^60)
    println("DEBUG: ForwardDiff Gradient with NaN Tracking")
    println("="^60)

    # Test 1: Objective value at x0
    println("\n[Test 1] Objective value at x0")
    loss = objective(x, p)
    println("  Loss: $loss")
    println("  Is finite: $(isfinite(loss))")

    if !isfinite(loss)
        println("  ✗ Objective itself is NaN/Inf - checking components...")
        debug_objective_components_detailed(x, p)
        return nothing
    end

    # Test 2: ForwardDiff with dual numbers
    println("\n[Test 2] ForwardDiff gradient computation")

    try
        # Use ForwardDiff directly with error tracking
        grad = ForwardDiff.gradient(x -> objective(x, p), x)

        nan_count = sum(isnan.(grad))
        inf_count = sum(isinf.(grad))

        println("  Gradient norm: $(norm(grad))")
        println("  NaN count: $nan_count")
        println("  Inf count: $inf_count")

        if nan_count > 0 || inf_count > 0
            println("  ✗ Gradient contains invalid values!")

            # Find which parameters have NaN gradients
            for (i, g) in enumerate(grad)
                if !isfinite(g)
                    println("    Parameter $i (x[$i] = $(x[i])): gradient = $g")
                end
            end

            # Test each parameter individually
            println("\n[Test 3] Parameter-by-parameter gradient test")
            debug_individual_gradients(x, p)

            return nothing
        else
            println("  ✓ Gradient is clean")
            return grad
        end

    catch e
        println("  ✗ ForwardDiff failed with exception: $e")
        println("  This often means NaN in dual number propagation")
        return nothing
    end
end

function debug_objective_components_detailed(x, p)
    """Check each component of objective for NaN"""
    println("\n" * "-"^60)
    println("Component Analysis:")
    println("-"^60)

    try
        dp = update_params(p.model, x)
        println("✓ update_params succeeded")
    catch e
        println("✗ update_params failed: $e")
        return
    end

    try
        paths, solver_penalty = solve_model_autodiff(dp)
        println("✓ solve_model_autodiff succeeded")
        println("  Solver penalty: $solver_penalty")

        if paths === nothing
            println("✗ paths is nothing - solver failed silently")
            debug_model_solve_detailed(x, p)
            return
        end

        # Check every path variable
        println("\n  Path variables check:")
        for (key, vec) in paths
            nan_count = sum(isnan.(vec))
            inf_count = sum(isinf.(vec))
            finite_vals = vec[isfinite.(vec)]

            if nan_count > 0
                println("    ✗ :$key has $nan_count NaN values")
            end
            if inf_count > 0
                println("    ✗ :$key has $inf_count Inf values")
            end
            if length(finite_vals) > 0
                println("    :$key range: [$(minimum(finite_vals)), $(maximum(finite_vals))]")
            end
        end

    catch e
        println("✗ solve_model_autodiff failed: $e")
        debug_model_solve_detailed(x, p)
        return
    end

    # Test penalty functions
    println("\n  Penalty functions:")
    try
        pos = positivity_penalty(paths)
        println("    positivity_penalty: $pos (finite: $(isfinite(pos)))")
    catch e
        println("    ✗ positivity_penalty failed: $e")
    end

    try
        explode = explosion_penalty(paths)
        println("    explosion_penalty: $explode (finite: $(isfinite(explode)))")
    catch e
        println("    ✗ explosion_penalty failed: $e")
    end

    return try
        osc = oscillation_score(paths[:Y])
        println("    oscillation_score: $osc (finite: $(isfinite(osc)))")
    catch e
        println("    ✗ oscillation_score failed: $e")
    end
end

function debug_individual_gradients(x, p; ε = 1.0e-5)
    """Test gradient for each parameter individually using finite differences"""
    println("\n" * "-"^60)
    println("Individual Parameter Gradient Test (Finite Difference):")
    println("-"^60)

    base_loss = objective(x, p)
    println("Base loss: $base_loss")

    for i in eachindex(x)
        x_plus = copy(x)
        x_plus[i] += ε

        try
            loss_plus = objective(x_plus, p)
            fd_grad = (loss_plus - base_loss) / ε

            status = isfinite(loss_plus) && isfinite(fd_grad) ? "✓" : "✗"
            println("$status Param $i (x[$i] = $(x[i])): loss=$loss_plus, grad=$fd_grad")

        catch e
            println("✗ Param $i: objective failed - $e")
        end
    end
    return
end

function debug_model_solve_detailed(x, p)
    """Debug the model solve step-by-step to find where NaN enters"""
    println("\n" * "="^60)
    println("DEBUG: Model Solve Step-by-Step (NaN Tracking)")
    println("="^60)

    dp = update_params(p.model, x)
    T = length(dp.model.time.grid)
    m = dp.model

    paths = Dict{Symbol, Vector{Float64}}()
    for v in m.variables
        paths[v.name] = zeros(Float64, T)
    end

    u = copy(dp.u0)
    println("Initial u0: $u")
    println("Time steps: $T")

    for t in 1:min(10, T)  # Check first 10 steps
        println("\n--- Time step $t ---")

        try
            θt = build_context_zygote(dp, t, paths)
        catch e
            println("✗ build_context failed at t=$t: $e")
            break
        end

        try
            prob = NonlinearProblem(m.nulls, u, θt, autodiff = false)
            sol = solve(
                prob, NewtonRaphson();
                maxiters = 100,
                abstol = 1.0e-10,
                reltol = 1.0e-10,
                fail_on_nonconvergence = false
            )

            println("  Solver retcode: $(sol.retcode)")
            println("  Solution: $(sol.u)")

            if !SciMLBase.successful_retcode(sol)
                println("  ✗ Solver failed at t=$t")
                break
            end

            if any(isnan.(sol.u))
                println("  ✗ NaN in solution at t=$t!")
                println("  Context keys: $(keys(θt))")
                for (k, v) in θt
                    if !isfinite(v)
                        println("    $k = $v (NOT FINITE)")
                    end
                end
                break
            end

            if any(isinf.(sol.u))
                println("  ✗ Inf in solution at t=$t!")
                break
            end

            # Store and continue
            for i in eachindex(sol.u)
                paths[m.variables[i].name][t] = sol.u[i]
            end
            u .= sol.u

            println("  ✓ Step $t completed successfully")

        catch e
            println("  ✗ Exception at t=$t: $e")
            break
        end
    end
    return
end

# Usage:
# debug_gradient_detailed(x0, p)
