using Optimization, OptimizationBBO, OptimizationOptimJL
using ForwardDiff
using PKAssetPrices
using StatsBase

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
optf = OptimizationFunction(objective, ADTypes.AutoForwardDiff())
prob = OptimizationProblem(
    optf, x0, p,
    lb = lb,
    ub = ub
)
sol = solve(prob, OptimizationOptimJL.SAMIN(), callback = callback)
@info sol
