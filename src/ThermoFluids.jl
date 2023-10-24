module ThermoFluids
#using CSV, DataFrames, Unitful
using Pluto
include("lookup.jl")
export lookup
export UnitfulAero
end
