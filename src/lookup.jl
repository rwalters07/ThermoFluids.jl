### A Pluto.jl notebook ###
# v0.19.29

using Markdown
using InteractiveUtils

# ╔═╡ 47eaba90-6479-11ee-2550-0961cb8cfc9b
using CSV, DataFrames, Unitful

# ╔═╡ bcc57694-b77b-43eb-83d2-34eecc113a76
module UnitfulAero; using Unitful; 
	@unit nmi "nautical mile" NautMile 1852u"m" false;
	# https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication330e2008.pdf 
	Unitful.register(UnitfulAero);
	@unit kt     "kt"    Knot        1u"nmi/hr" 				false;
	@unit hp     "hp"    HorsePower  550u"lbf*ft/s" 			false;
	@unit lbm    "lbm"   Poundmass   1u"lbf"/32.174u"ft/s^2" 	false;
	@unit ton    "ton"   Ton         200u"btu/minute" 			false;
end

# ╔═╡ 40cb4a74-290f-4f71-bb78-1cf9fbfd8205
waterPath = joinpath(@__DIR__, "water.csv")

# ╔═╡ 22397a6f-3557-4e02-83ad-ef9f343121cd
steamPath = joinpath(@__DIR__, "steam.csv")

# ╔═╡ 6441ca04-91ad-47b4-96aa-f98010da0eee
begin
	fileName = "water.csv"; #fileName that has the air tables
	water = CSV.File(waterPath,header=6) |> DataFrame; #look for the named file in the same working directory as the pluto notebook, load it, and convert to a DataFrame
	water.T .= (water.T.+273.15).*1u"K" .|>u"°C";
	water.P .= (water.P).*1u"kPa" ;
	water.vf .= water.vf*1u"m^3/kg";
	water.vg .= water.vg*1u"m^3/kg";
	water.uf .= water.uf*1u"kJ/kg";
	water.ug .= water.ug*1u"kJ/kg";
	water.hf .= water.hf*1u"kJ/kg";
	water.hfg .= water.hfg*1u"kJ/kg";
	water.hg .= water.hg*1u"kJ/kg";
	water.sf .= water.sf*1u"kJ/(kg*K)";
	water.sg .= water.sg*1u"kJ/(kg*K)";
end

# ╔═╡ 056279ba-e0eb-49c1-8b03-63964762234a
begin 
	steam = CSV.File(steamPath,header=1) |> DataFrame;
	steam.T .= (steam.T.+273.15).*1u"K" .|>u"°C";
	steam.P .= (steam.P).*1u"kPa" ;
	steam.v .= steam.v*1u"m^3/kg";
	steam.u .= steam.u*1u"kJ/kg";
	steam.h .= steam.h*1u"kJ/kg";
	steam.s .= steam.s*1u"kJ/(kg*K)";
end

# ╔═╡ b6faf781-a3af-4a04-9980-19e464fb2930
function lerp(xs,ys,x)
	if first(xs.<=x) == false
		lerpindexH = findlast(xs.>=x)
		lerpindexL = findfirst(xs.<=x)

	else
		lerpindexH = findlast(xs.<=x)
		lerpindexL=findfirst(xs.>=x)
	end
	if lerpindexL==lerpindexH #right on value, no need to interpolate
		y=ys[lerpindexH]
	else #off of value interpolate
		y = (x-xs[lerpindexL])*(ys[lerpindexH]-ys[lerpindexL])/(xs[lerpindexH]-xs[lerpindexL])+ys[lerpindexL]
	end
end

# ╔═╡ cec998ef-bb0a-49be-81ee-7a834b2d1f24
function lookupPh(P)
			Plow = steam.P[findlast(steam.P.<=P)]
			Phigh = steam.P[findfirst(steam.P.>=P)]
			steamLow = steam[(steam.P .== Plow), :]
			s = props[nonTkey]
			rowlow = steamLow[findfirst(steamLow.h.<=s),:]
			rowhigh = steamLow[findfirst(steamLow.h.>=s),:]
			x = (s-rowlow.h)/(rowhigh.h-rowlow.h)
			T = rowlow.T+x*(rowhigh.T-rowlow.T)
end

# ╔═╡ e9ec2cec-f5a9-47ea-885e-5e1052d5bb83
function lookupPu(P)
			Plow = steam.P[findlast(steam.P.<=P)]
			Phigh = steam.P[findfirst(steam.P.>=P)]
			steamLow = steam[(steam.P .== Plow), :]
			s = props[nonTkey]
			rowlow = steamLow[findfirst(steamLow.u.<=s),:]
			rowhigh = steamLow[findfirst(steamLow.u.>=s),:]
			x = (s-rowlow.u)/(rowhigh.u-rowlow.u)
			T = rowlow.T+x*(rowhigh.T-rowlow.T)
end

# ╔═╡ df80d49c-7cbb-4182-870a-bc869a2af1a7
function lookupPv(P)
			Plow = steam.P[findlast(steam.P.<=P)]
			Phigh = steam.P[findfirst(steam.P.>=P)]
			steamLow = steam[(steam.P .== Plow), :]
			s = props[nonTkey]
			rowlow = steamLow[findfirst(steamLow.v.<=s),:]
			rowhigh = steamLow[findfirst(steamLow.v.>=s),:]
			x = (s-rowlow.v)/(rowhigh.v-rowlow.v)
			T = rowlow.T+x*(rowhigh.T-rowlow.T)
end

# ╔═╡ d3de6a31-d0e8-436a-a8ea-d36b32f2fe29
struct properties #structure to hold property values
	T
	P
	v
	u
	h
	s
	x
	region
end

# ╔═╡ 6fc47e56-d700-468e-89ca-61be2bb55041
function lookupTP(prop1,prop2)
	props = Dict(prop1,prop2)
	#println(keys(props))
	T = props["T"] |>u"°C"
	P = props["P"] |>u"kPa"
	if P > maximum(water.P)
		Tsat = T - .1u"K"
	else
		Tsat = lerp(water.P,water.T,P)
	end
	if T<Tsat
		state = properties(T,P,lerp(water.T,water.vf,T),lerp(water.T,water.uf,T),lerp(water.T,water.hf,T),lerp(water.T,water.sf,T),"NA","CLR")
	elseif Tsat == T
		"SMR T & P are not independent use a different property"
	else
		"SHR"
		if sum(P .== unique(steam.P)) == 1 #exact table pressure value
			steam1 = steam[(steam.P .== P), :]
			#lerp(steam1.T,steam1.v,T)
			 #names(steam1)
			#lerp(steam1.T,steam1.v,T)
			properties(T,P,lerp(steam1.T,steam1.v,T),lerp(steam1.T,steam1.u,T),lerp(steam1.T,steam1.h,T),lerp(steam1.T,steam1.s,T),"NA","SHR")
		else
			"interpolate pressures"
			# P .> unique(steam.P)
			# P .< unique(steam.P)
			Plow = steam.P[findlast(steam.P.<=P)]
			Phigh = steam.P[findfirst(steam.P.>=P)]
			steamLow = steam[(steam.P .== Plow), :]
			propLow = properties(T,P,lerp(steamLow.T,steamLow.v,T),lerp(steamLow.T,steamLow.u,T),lerp(steamLow.T,steamLow.h,T),lerp(steamLow.T,steamLow.s,T),"NA","SHR")
			steamHigh = steam[(steam.P .== Phigh), :]
			propHigh = properties(T,P,lerp(steamHigh.T,steamHigh.v,T),lerp(steamHigh.T,steamHigh.u,T),lerp(steamHigh.T,steamHigh.h,T),lerp(steamHigh.T,steamHigh.s,T),"NA","SHR")
			percent = (P-Plow)/(Phigh-Plow)
			v = (propHigh.v-propLow.v)*percent+propLow.v
			u = (propHigh.u-propLow.u)*percent+propLow.u
			h = (propHigh.h-propLow.h)*percent+propLow.h
			s = (propHigh.s-propLow.s)*percent+propLow.s
			properties(T,P,v,u,h,s,"NA","SHR")#,percent
		end
	end
	#state	
end

# ╔═╡ 63eacb73-3b9d-4d62-a592-5ac41937d4dd
function lookup(prop1,prop2)
	props = Dict(prop1,prop2)
	keyCheck = ["T","P","v","u","h","s","x"]
	propType = [false,false,false,false,false,false,false]
	n = length(propType)
	for i in 1:length(keyCheck)
		#println(haskey(props,keyCheck[i]))
		propType[i]=haskey(props,keyCheck[i])
	end
	# println(propType)
	# println(water[propType])
	if sum(propType[1:2])==2 #rule 1 Temp & Pressure
		"rule1"
		lookupTP(prop1,prop2)
	elseif propType[1]+sum(propType[3:n]) == 2 #rule 2 Temp & non-pressure
		"rule2" 
		#props
		lookupT2(prop1,prop2)
		#lookupT2(prop1,prop2)
	elseif sum(propType[2:n]) ==2 #rule 3 Pres & non-temperature
		"rule3" #
		lookupP3(prop1,prop2)
	else
		"look up must include either a temp or pressure"
	end
end

# ╔═╡ 2dbdef30-13cb-44db-bb23-837885a14c67
function lookupT2(prop1,prop2)
	props = Dict(prop1,prop2)
	keyCheck = ["v","u","h","s"]
	T = props["T"] |>u"°C"
	nonTkeyTest = collect(keys(props))[1]=="T"
	if nonTkeyTest == false
		nonTkey = collect(keys(props))[1]
	else
		nonTkey = collect(keys(props))[2]
	end
	if nonTkey=="x"
		"SMR"
		quality = props[nonTkey]
		P = lerp(water.T,water.P,T)
		u = lerp(water.T,water.uf,T)+quality*(lerp(water.T,water.ug,T)-lerp(water.T,water.uf,T))
		v = lerp(water.T,water.vf,T)+quality*(lerp(water.T,water.vg,T)-lerp(water.T,water.vf,T))
		h = lerp(water.T,water.hf,T)+quality*(lerp(water.T,water.hg,T)-lerp(water.T,water.hf,T))
		s = lerp(water.T,water.sf,T)+quality*(lerp(water.T,water.sg,T)-lerp(water.T,water.sf,T))
		return properties(T,P,v,u,h,s,quality,"SMR")
	end
	yfall = water[:,findfirst(occursin.(nonTkey, names(water)))]
	ygall = water[:,findlast(occursin.(nonTkey, names(water)))]
	yg = lerp(water.T,ygall,T)
	ysat = lerp(water.T,yfall,T)
	y=props[nonTkey]
	if y<ysat #CLR
		properties(T,lerp(water.T,water.P,T),lerp(water.T,water.vf,T),lerp(water.T,water.uf,T),lerp(water.T,water.hf,T),lerp(water.T,water.sf,T),"NA","CLR")
	elseif y>yg
		"SHR"
			#Tlow = steam.T[findlast(steam.T.<=T)]

			if nonTkey=="s"
				Tlow = steam.T[findlast(steam.T.<=T)]
				Thigh = steam.T[findfirst(steam.T.>=T)]
				steamLow = steam[(steam.T .== Tlow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.s.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.s.>=s),:]
				x = (s-rowlow.s)/(rowhigh.s-rowlow.s)
				P = rowlow.P+x*(rowhigh.P-rowlow.P)
				lookup("T"=>T,"P"=>P)
				#println("found with P and s")
			elseif nonTkey=="h"
				Tlow = steam.T[findlast(steam.T.<=T)]
				Thigh = steam.T[findfirst(steam.T.>=T)]
				steamLow = steam[(steam.T .== Tlow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.h.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.h.>=s),:]
				x = (s-rowlow.h)/(rowhigh.h-rowlow.h)
				P = rowlow.P+x*(rowhigh.P-rowlow.P)
				lookup("T"=>T,"P"=>P)
				#println("found with P and h")
			elseif nonTkey=="u"
				Tlow = steam.T[findlast(steam.T.<=T)]
				Thigh = steam.T[findfirst(steam.T.>=T)]
				steamLow = steam[(steam.T .== Tlow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.u.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.u.>=s),:]
				x = (s-rowlow.u)/(rowhigh.u-rowlow.u)
				P = rowlow.P+x*(rowhigh.P-rowlow.P)
				lookup("T"=>T,"P"=>P)
				#println("found with P and u")
			else #must be v
				Tlow = steam.T[findlast(steam.T.<=T)]
				Thigh = steam.T[findfirst(steam.T.>=T)]
				steamLow = steam[(steam.T .== Tlow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.v.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.v.>=s),:]
				x = (s-rowlow.v)/(rowhigh.v-rowlow.v)
				P = rowlow.P+x*(rowhigh.P-rowlow.P)
				lookup("T"=>T,"P"=>P)
				#println("found with P and v")
			end
			# Phigh = steam.P[findfirst(steam.P.>=P)]
			# steamLow = steam[(steam.P .== Plow), :]
			# propLow = properties(T,P,lerp(steamLow.T,steamLow.v,T),lerp(steamLow.T,steamLow.u,T),lerp(steamLow.T,steamLow.h,T),lerp(steamLow.T,steamLow.s,T),"SHR")
			# steamHigh = steam[(steam.P .== Phigh), :]
			# propHigh = properties(T,P,lerp(steamHigh.T,steamHigh.v,T),lerp(steamHigh.T,steamHigh.u,T),lerp(steamHigh.T,steamHigh.h,T),lerp(steamHigh.T,steamHigh.s,T),"SHR")
			# percent = (P-Plow)/(Phigh-Plow)
			# v = (propHigh.v-propLow.v)*percent+propLow.v
			# u = (propHigh.u-propLow.u)*percent+propLow.u
			# h = (propHigh.h-propLow.h)*percent+propLow.h
			# s = (propHigh.s-propLow.s)*percent+propLow.s
			# properties(T,P,v,u,h,s,"SHR")
	else
		"SMR"
		quality = (y-ysat)/(yg-ysat)
		P = lerp(water.T,water.P,T)
		u = lerp(water.T,water.uf,T)+quality*(lerp(water.T,water.ug,T)-lerp(water.T,water.uf,T))
		v = lerp(water.T,water.vf,T)+quality*(lerp(water.T,water.vg,T)-lerp(water.T,water.vf,T))
		h = lerp(water.T,water.hf,T)+quality*(lerp(water.T,water.hg,T)-lerp(water.T,water.hf,T))
		s = lerp(water.T,water.sf,T)+quality*(lerp(water.T,water.sg,T)-lerp(water.T,water.sf,T))
		properties(T,P,v,u,h,s,quality,"SMR")
	end
	#props[nonTkey]>yg
end

# ╔═╡ cc8d5afb-2a9c-419e-bc93-06294f1a56e1
function lookupP3(prop1,prop2)
	props = Dict(prop1,prop2)
	keyCheck = ["v","u","h","s","x"]
	P = props["P"] |>u"kPa"
	nonTkeyTest = collect(keys(props))[1]=="P"
	#println(nonTkeyTest)
	if nonTkeyTest == false
		nonTkey = collect(keys(props))[1]
	else
		nonTkey = collect(keys(props))[2]
	end
	if nonTkey=="x"
		"SMR"
		quality = props[nonTkey]
		T = lerp(water.P,water.T,P)
		u = lerp(water.P,water.uf,P)+quality*(lerp(water.P,water.ug,P)-lerp(water.P,water.uf,P))
		v = lerp(water.P,water.vf,P)+quality*(lerp(water.P,water.vg,P)-lerp(water.P,water.vf,P))
		h = lerp(water.P,water.hf,P)+quality*(lerp(water.P,water.hg,P)-lerp(water.P,water.hf,P))
		s = lerp(water.P,water.sf,P)+quality*(lerp(water.P,water.sg,P)-lerp(water.P,water.sf,P))
		return properties(T,P,v,u,h,s,quality,"SMR")
	end
	
	yfall = water[:,findfirst(occursin.(nonTkey, names(water)))]
	ygall = water[:,findlast(occursin.(nonTkey, names(water)))]
	yg = lerp(water.P,ygall,P)
	ysat = lerp(water.P,yfall,P)
	y=props[nonTkey]


	
	if y<ysat #CLR #Should be using Temp & not Pressure!
		#println("CLR")
		if nonTkey=="s"
			h = lerp(water.sf,water.hf,y)+lerp(water.sf,water.vf,y)*P |>u"kJ/kg"
			T = lerp(water.hf,water.T,h)
			properties(lerp(water.hf,water.T,h),P,lerp(water.sf,water.vf,y),lerp(water.sf,water.uf,y),h,y,"NA","CLR")#,lookupTP("P"=>P,"T"=>T)
		else nonTkey=="h"
			#println("h")
			T = lerp(water.hf,water.T,y)
			lookup("P"=>P,"T"=>T)
		end
		
	elseif y>yg
		"SHR"

			if nonTkey=="s"
				Plow = steam.P[findlast(steam.P.<=P)]
				Phigh = steam.P[findfirst(steam.P.>=P)]
				steamLow = steam[(steam.P .== Plow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.s.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.s.>=s),:]
				x = (s-rowlow.s)/(rowhigh.s-rowlow.s)
				T = rowlow.T+x*(rowhigh.T-rowlow.T)
				lookup("T"=>T,"P"=>P)
				#println("found with P and s")
			elseif nonTkey=="h"
				Plow = steam.P[findlast(steam.P.<=P)]
				Phigh = steam.P[findfirst(steam.P.>=P)]
				steamLow = steam[(steam.P .== Plow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.h.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.h.>=s),:]
				x = (s-rowlow.h)/(rowhigh.h-rowlow.h)
				T = rowlow.T+x*(rowhigh.T-rowlow.T)
				lookup("T"=>T,"P"=>P)
				#println("found with P and h")
			elseif nonTkey=="u"
				Plow = steam.P[findlast(steam.P.<=P)]
				Phigh = steam.P[findfirst(steam.P.>=P)]
				steamLow = steam[(steam.P .== Plow), :]
				s = props[nonTkey]
				rowlow = steamLow[findfirst(steamLow.u.<=s),:]
				rowhigh = steamLow[findfirst(steamLow.u.>=s),:]
				x = (s-rowlow.u)/(rowhigh.u-rowlow.u)
				T = rowlow.T+x*(rowhigh.T-rowlow.T)
				lookup("T"=>T,"P"=>P)
				#println("found with P and u")
			else #must be v
				Plow = steam.P[findlast(steam.P.<=P)]
				Phigh = steam.P[findfirst(steam.P.>=P)]
				steamLow = steam[(steam.P .== Plow), :]
				# s = props[nonTkey]
				# rowlow = steamLow[findfirst(steamLow.v.<=s),:]
				# rowhigh = steamLow[findfirst(steamLow.v.>=s),:]
				# x = (s-rowlow.v)/(rowhigh.v-rowlow.v)
				# T = rowlow.T+x*(rowhigh.T-rowlow.T)
				# lookup("T"=>T,"P"=>P)
				#println("found with P and v")
			end
			
			#lookupTP("P"=>P,"T"=>T)
			# slow = steamLow.s[findfirst(steamLow.s.<=s)]
			# shigh = steamLow.s[findfirst(steamLow.s.>=s)]
			# x = (s-slow)/(shigh-slow)
			# Tlow = steamLow.T[findfirst(steamLow.s.<=s)]
			# Thigh = steamLow.T[findfirst(steamLow.s.>=s)]
			# T = Tlow+x*(Thigh-Tlow)
			# lookupTP("P"=>P,"T"=>T)
			# shigh = steamLow.s[findlast(steam.s.<=s)]
			# propLow = properties(lerp(steamLow.P,steamLow.T,P),P,lerp(steamLow.P,steamLow.v,P),lerp(steamLow.P,steamLow.u,P),lerp(steamLow.P,steamLow.h,P),lerp(steamLow.P,steamLow.s,P),"SHR")
			# steamHigh = steam[(steam.P .== Phigh), :]
			# propHigh = properties(T,P,lerp(steamHigh.T,steamHigh.v,T),lerp(steamHigh.T,steamHigh.u,T),lerp(steamHigh.T,steamHigh.h,T),lerp(steamHigh.T,steamHigh.s,T),"SHR")
			# percent = (P-Plow)/(Phigh-Plow)
			# v = (propHigh.v-propLow.v)*percent+propLow.v
			# u = (propHigh.u-propLow.u)*percent+propLow.u
			# h = (propHigh.h-propLow.h)*percent+propLow.h
			# s = (propHigh.s-propLow.s)*percent+propLow.s
			# properties(T,P,v,u,h,s,"SHR")
	else
		"SMR"
		quality = (y-ysat)/(yg-ysat)
		T = lerp(water.P,water.T,P)
		u = lerp(water.P,water.uf,P)+quality*(lerp(water.P,water.ug,P)-lerp(water.P,water.uf,P))
		v = lerp(water.P,water.vf,P)+quality*(lerp(water.P,water.vg,P)-lerp(water.P,water.vf,P))
		h = lerp(water.P,water.hf,P)+quality*(lerp(water.P,water.hg,P)-lerp(water.P,water.hf,P))
		s = lerp(water.P,water.sf,P)+quality*(lerp(water.P,water.sg,P)-lerp(water.P,water.sf,P))
		properties(T,P,v,u,h,s,quality,"SMR")
	end
	#props[nonTkey]>yg
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
CSV = "~0.10.11"
DataFrames = "~1.6.1"
Unitful = "~1.17.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.3"
manifest_format = "2.0"
project_hash = "75694209c8e9df94d78e4dcf8c01886d474239bb"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "44dbf560808d49041989b8a96cae4cffbeb7966a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.11"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "02aa26a4cf76381be7f66e020a3eddeb27b0a092"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.2"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "8a62af3e248a8c4bad6b32cbbe663ae02275e32c"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.10.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3dbd312d370723b6bb43ba9d02fc36abade4518d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.15"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "2e73fe17cac3c62ad1aebe70d44c963c3cfdc3e3"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.2"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "716e24b21538abc91f6205fd1d8363f39b442851"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "ee094908d720185ddbdc58dbe0c1cbe35453ec7a"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.7"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "04bdff0b09c65ff3e06a05e3eb7b120223da3d39"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "a1f34829d5ac0ef499f6d84428bd6b4c71f02ead"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "a72d22c7e13fe2de562feda8645aa134712a87ee"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.17.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═47eaba90-6479-11ee-2550-0961cb8cfc9b
# ╠═bcc57694-b77b-43eb-83d2-34eecc113a76
# ╠═40cb4a74-290f-4f71-bb78-1cf9fbfd8205
# ╠═22397a6f-3557-4e02-83ad-ef9f343121cd
# ╠═6441ca04-91ad-47b4-96aa-f98010da0eee
# ╠═056279ba-e0eb-49c1-8b03-63964762234a
# ╠═b6faf781-a3af-4a04-9980-19e464fb2930
# ╠═6fc47e56-d700-468e-89ca-61be2bb55041
# ╠═2dbdef30-13cb-44db-bb23-837885a14c67
# ╠═cec998ef-bb0a-49be-81ee-7a834b2d1f24
# ╠═e9ec2cec-f5a9-47ea-885e-5e1052d5bb83
# ╠═df80d49c-7cbb-4182-870a-bc869a2af1a7
# ╠═cc8d5afb-2a9c-419e-bc93-06294f1a56e1
# ╠═d3de6a31-d0e8-436a-a8ea-d36b32f2fe29
# ╠═63eacb73-3b9d-4d62-a592-5ac41937d4dd
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
