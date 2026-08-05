module Dashboard

using Dash
using ..Static
using ..Dynamic

include("styles.jl")
include("components.jl")
include("tables.jl")
include("plots.jl")
include("results.jl")
include("dynamic_components.jl")
include("views.jl")
include("app.jl")
include("callbacks.jl")
include("dynamic_callbacks.jl")

function run(app; host = "127.0.0.1", port = 8050, debug = false)
    return run_server(app, host, port; debug)
end

end
