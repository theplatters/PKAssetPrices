using Test
using PKAssetPrices

@testset "PKAssetPrices" begin
    include("test_core.jl")
    include("test_static.jl")
    include("test_helpers.jl")
    include("test_dynamic.jl")
    include("test_models.jl")
    include("test_dashboard.jl")
    include("test_plotting.jl")
end
