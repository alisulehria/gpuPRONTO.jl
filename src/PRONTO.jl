# PRONTO.jl v0.5.0_dev
module PRONTO

using FunctionWrappers
import FunctionWrappers: FunctionWrapper
using StaticArrays
using FastClosures #TODO: test speed
using Base: @kwdef

using Interpolations # data storage/resampling

import LinearAlgebra # collision with lu!
import LinearAlgebra: mul!, I
using MatrixEquations # provides arec


#TODO: #FUTURE: using OrdinaryDiffEq
using DifferentialEquations

using Symbolics # code generation
import Symbolics: derivative # code generation
using SymbolicUtils.Code #MAYBE: code generation
export Num # this reexport is needed for codegen macro scoping

using ThreadTools # tmap for code generation
using UnicodePlots # data representation

using Dates: now

using MacroTools
import MacroTools: @capture


using Base: OneTo
using Base: fieldindex
import Base: extrema, length, eachindex, show, size, eltype, getproperty, getindex


export pronto
export info #TODO: does this need to be exported?

export @tick,@tock,@clock #TODO: get rid of alltogether?

#TODO: reconsider export
export ODE, Buffer
export preview

# ----------------------------------- model type ----------------------------------- #

export Model
export nx,nu,nθ

# abstract type Model{NX,NU,NΘ} <: FieldVector{NΘ,Float64} end

# nx(::Model{NX,NU,NΘ}) where {NX,NU,NΘ} = NX
# nu(::Model{NX,NU,NΘ}) where {NX,NU,NΘ} = NU
# nθ(::Model{NX,NU,NΘ}) where {NX,NU,NΘ} = NΘ

# nx(::Type{<:Model{NX,NU,NΘ}}) where {NX,NU,NΘ} = NX
# nu(::Type{<:Model{NX,NU,NΘ}}) where {NX,NU,NΘ} = NU
# nθ(::Type{<:Model{NX,NU,NΘ}}) where {NX,NU,NΘ} = NΘ

abstract type Model{NX,NU} end
# fields can be Scalars or SArrays
#MAYBE: restrict this?

nx(::Model{NX,NU}) where {NX,NU} = NX
nu(::Model{NX,NU}) where {NX,NU} = NU
nθ(::T) where {T<:Model} = nθ(T)

nx(::Type{<:Model{NX,NU}}) where {NX,NU} = NX
nu(::Type{<:Model{NX,NU}}) where {NX,NU} = NU
nθ(T::Type{<:Model}) = fieldcount(T)

# not used
inv!(A) = LinearAlgebra.inv!(LinearAlgebra.cholesky!(Hermitian(A)))


show(io::IO, ::T) where {T<:Model} = print(io, "$T model")

iscompact(io) = get(io, :compact, false)
function show(io::IO,::MIME"text/plain", θ::T) where {T<:Model}
    if iscompact(io)
        print(io, "$T model")
    else
        println(io, "$(as_bold(T)) model with parameter values:")
        for name in fieldnames(T)
            println(io, "  $name: $(getfield(θ,name))")
        end
    end
end


# # facilitate symbolic differentiation of model
# struct SymbolicModel{T}
#     vars
# end
export SymModel
struct SymModel{T} end

# symmodel.kq -> variables fitting 
getproperty(::SymModel{T}, name::Symbol) where {T<:Model} = symbolic(name, fieldtype(T, name))
propertynames(::SymModel{T}) where T = fieldnames(T)

symbolic(T::Type{<:Model}) = SymModel{T}()
export symbolic

# for models
# symbolic(T::Model)

# for tracing functions
# symbolic(fxn::Function, T::Model)

# scalar variables and fields (default)
symbolic(name::Symbol, ::Type{<:Any}) = symbolic(name)
symbolic(name::Symbol) = first(@variables $name)

# array variables and fields
symbolic(name::Symbol, T::Type{<:StaticArray}) = symbolic(name, Size(T))
function symbolic(name::Symbol, ::Size{S}) where S
    dims = [1:N for N in S]
    collect(first(@variables $name[dims...]))
end

# non-static arrays
symbolic(name::Symbol, T::Type{<:AbstractArray}) = error("Cannot create symbolic representation of variable-sized array. Consider using StaticArrays.")

# symfield(::SArray{S,T}, name) where {S,T} = first(@variables name[])
# getproperty(::SymModel{T}, name::Symbol) where {T<:Model} = fieldtype(T, name)

# function SymbolicModel(T::DataType)
#     @variables θ[1:nθ(T)]
#     SymbolicModel{T}(collect(θ))
# end

# getindex(θ::SymbolicModel{T}, i::Integer) where {T} = getindex(getfield(θ, :vars), i)
# getproperty(θ::SymbolicModel{T}, name::Symbol) where {T} = getindex(θ, fieldindex(T, name))

# symindex(T, name) = findfirst(isequal(name), fieldnames(T))
# symfields(T,θ) = Tuple(θ[symindex(T, name)] for name in fieldnames(T))

# function SymbolicModel(T)
#     @variables θ[1:nθ(T)]
#     T{Num}(; zip(fieldnames(T), symfields(T, collect(θ)))...)
# end

# ----------------------------------- #. helpers ----------------------------------- #
include("helpers.jl")


#can I finally deprecate this? :)
# views(::Model{NX,NU,NΘ},ξ) where {NX,NU,NΘ} = (@view ξ[1:NX]),(@view ξ[NX+1:end])


# ----------------------------------- #. model functions ----------------------------------- #

#MAYBE: just throw a method error?
struct ModelDefError <: Exception
    θ::Model
end

function Base.showerror(io::IO, e::ModelDefError)
    T = typeof(e.θ)
    print(io, "PRONTO is missing method definitions for the $T model.\n")
end




# by default, this is the solution to the algebraic riccati equation at tf
# user can override this behavior for a model type by defining PRONTO.Pf(α,μ,tf,θ::MyModel)
function Pf(α,μ,tf,θ::Model{NX}) where {NX}
    Ar = fx(α, μ, tf, θ)
    Br = fu(α, μ, tf, θ)
    Qr = Q(α, μ, tf, θ)
    Rr = R(α, μ, tf, θ)
    Pf,_ = arec(Ar,Br*(Rr\Br'),Qr)
    return SMatrix{NX,NX,Float64}(Pf)
end



# ----------------------------------- #. components ----------------------------------- #

include("kernels.jl") # placeholder solver kernel function definitions
include("codegen.jl") # takes derivatives, generates model functions
include("odes.jl") # wrappers for ODE solution handling
include("regulator.jl") # regulator for projection operator
include("projection.jl") # projected (closed loop) and guess (open loop) trajectories
include("optimizer.jl") # lagrangian, 1st/2nd order optimizer, search direction
include("cost.jl") # cost and cost derivatives
include("armijo.jl") # armijo step and projection



# ----------------------------------- pronto loop ----------------------------------- #

fwd(τ) = extrema(τ)
bkwd(τ) = reverse(fwd(τ))


# solves for x(t),u(t)'
function pronto(θ::Model{NX,NU}, x0::StaticVector, φ, τ; limitγ=false, tol = 1e-5, maxiters = 20,verbose=true) where {NX,NU}
    t0,tf = τ
    verbose && info(0, "starting PRONTO")

    for i in 1:maxiters
        # info(i, "iteration")
        # -------------- build regulator -------------- #
        # α,μ -> Kr,x,u
        verbose && iinfo("regulator")
        Kr = regulator(θ, φ, τ)
        verbose && iinfo("projection")
        ξ = projection(θ, x0, φ, Kr, τ)

        # -------------- search direction -------------- #
        # Kr,x,u -> z,v
        verbose && iinfo("lagrangian")
        λ = lagrangian(θ,ξ,φ,Kr,τ)
        verbose && iinfo("optimizer")
        Ko = optimizer(θ,λ,ξ,φ,τ)
        verbose && iinfo("using $(is2ndorder(Ko) ? "2nd" : "1st") order search")
        verbose && iinfo("costate")
        vo = costate(θ,λ,ξ,φ,Ko,τ)
        verbose && iinfo("search_direction")
        ζ = search_direction(θ,ξ,Ko,vo,τ)

        # -------------- cost/derivatives -------------- #
        verbose && iinfo("cost/derivs")

        Dh,D2g = cost_derivs(θ,λ,φ,ξ,ζ,τ)
        
        Dh > 0 && (info(i, "increased cost - quitting"); (return φ))
        -Dh < tol && (info(i-1, as_bold("PRONTO converged")); (return φ))

        # compute cost
        h = cost(ξ, τ)
        # verbose && iinfo(as_bold("h = $(h)\n"))
        # print(ξ)

        # -------------- select γ via armijo step -------------- #
        # γ = γmax; 
        aα=0.4; aβ=0.7
        γ = limitγ ? min(1, 1/maximum(maximum(ζ.x(t) for t in t0:0.0001:tf))) : 1.0

        local η
        while γ > aβ^25
            verbose && iinfo("armijo γ = $(round(γ; digits=6))")
            η = armijo_projection(θ,x0,ξ,ζ,γ,Kr,τ)
            g = cost(η, τ)
            h-g >= -aα*γ*Dh ? break : (γ *= aβ)
        end
        verbose && info(i, "Dh = $Dh, h = $h, γ = $γ") #TODO: 1st/2nd order

        φ = η
    end
    return φ
end


end # module