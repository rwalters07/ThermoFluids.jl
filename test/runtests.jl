using ThermoFluids
using Test
using Unitful

@testset "ThermoFluids.jl" begin
    # Write your tests here.
   @test lookup("x"=>0,"T"=>50u"°C").v == 0.0010121u"m^3/kg"
end
