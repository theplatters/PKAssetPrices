module Dashboard

using Dash
using ..Static

include("styles.jl")
include("views.jl")
include("components.jl")
include("app.jl")

run(app) = run_server(app, "0.0.0.0", 8050; debug = true)
end
