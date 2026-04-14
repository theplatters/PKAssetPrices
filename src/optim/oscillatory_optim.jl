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

    sol = Dynamic.solve_model(model)

    return sol
end

function explosion_penalty(y)
    return sum(max(0, abs(xi) - 100)^2 for xi in reduce(vcat, values(y)))
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


p = Dict(
    :x => [0.3, 10.5],
    :y => [0.3, 0.5]
)

positivity_penalty(p)


x0 = [0.008905350496328067, 0.037493422061853576, 0.48152300038241813, 0.24028386950622796, 0.11548465017702524, 0.17509632134056813, 0.35048918515442207, 0.9455059561651523, 0.6241246752385647, 0.044024262656295665]
x1 = [0.8463213035143698, 0.2550484113257094, 0.052025500689039134, 0.3184621806282828, 0.06425994550113504, 0.5006502538028674, 0.9706631007613131, 0.0005959482135358993, 0.29553658119280646, 0.31639299459056147]

function callback(state, loss)
    println("Iteration: $(state.iter), Loss: $loss, Params: $(state.u)")
    return false  # return true to stop optimization
end

p = (
    model = Dynamic.DynαQCr
)

lb = fill(0.0, 10)
ub = fill(1.0, 10)
prob = OptimizationProblem(
    objective, x0, p,
    lb = lb,
    ub = ub
)
sol = solve(prob, OptimizationBBO.BBO_generating_set_search(), callback = callback)
