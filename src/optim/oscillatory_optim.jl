using Optimization, OptimizationBBO
using ForwardDiff
using PKAssetPrices
using StatsBase

function positivity_penalty(paths)
    return sum(max(0, -xi)^2 for xi in reduce(vcat, values(paths)))
end

function objective(x, p)
    model = deepcopy(p)
    model.params[:c₀] = x[1]
    model.params[:c₁] = x[2]
    model.params[:i0] = x[3]
    model.params[:i1] = x[4]
    model.params[:i2] = x[5]
    model.params[:s0] = x[6]
    model.params[:s1] = x[7]
    model.params[:s2] = x[8]
    model.params[:γ] = x[9]
    model.params[:α₀] = x[10]
    model.params[:d0] = x[11]
    model.params[:d1] = x[12]
    model.params[:gₐ] = x[13]
    model.params[:m] = x[14]


    sol = Dynamic.solve_model(model)

    return - oscillation_score(sol.paths[:Y]) + positivity_penalty(sol.paths) + explosion_penalty(sol.paths)
end


function eval_model(x, p)
    model = deepcopy(p)
    model.params[:c₀] = x[1]
    model.params[:c₁] = x[2]
    model.params[:i0] = x[3]
    model.params[:i1] = x[4]
    model.params[:i2] = x[5]
    model.params[:s0] = x[6]
    model.params[:s1] = x[7]
    model.params[:s2] = x[8]
    model.params[:γ] = x[9]
    model.params[:α₀] = x[10]
    model.params[:d0] = x[11]
    model.params[:d1] = x[12]
    model.params[:gₐ] = x[13]
    model.params[:m] = x[14]

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

    # Penalty for explosion (values far from zero)

    return crossings + sign_changes
end


x0 = [0.8, 0.1, 0.01, 0.05, 0.01, 1.0, 0.1, 0.2, 0.5, 0.1, 5.0, 8.0, 0.03, 0.15]

Dict(k => maximum(v) for (k, v) in eval_model(x0, Dynamic.DynαQCr).paths)


function callback(state, loss)
    println("Iteration: $(state.iter), Loss: $loss, Params: $(state.u)")
    return false  # return true to stop optimization
end

p = (
    model = Dynamic.DynαQCr
)

lb = fill(0.0, 14)
ub = [fill(1.0, 10); 12.0; 12.0; 1.0; 0.4]
prob = OptimizationProblem(
    objective, x0, p,
    lb = lb,
    ub = ub
)
sol = solve(prob, OptimizationBBO.BBO_xnes(), callback = callback)
