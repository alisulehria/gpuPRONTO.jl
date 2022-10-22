## ----------------------------------- module ----------------------------------- ##
module PRONTO

using Symbolics
using Symbolics: derivative
include("../src/autodiff.jl")

abstract type Model{NX,NU} end

f(M::Model,x,u) = @error "function f undefined for models of type $(typeof(M))"
fx(M::Model,x,u) = @error "function fx undefined for models of type $(typeof(M))"


nx(::Model{NX,NU}) where {NX,NU} = NX
nu(::Model{NX,NU}) where {NX,NU} = NU
# nθ(::Model) doesn't actually matter!


# pronto(M::Model, x0, T/dt, θ, xg, ug)
# pronto(M, x0, T/dt, θ, guess(...)...)
function pronto(M::Model{NX,NU},t,args...) where {NX,NU}
    f(M,x,u)
end
# fallback: if type is given, creates an instance
pronto(T::DataType, args...) = pronto(T(), args...)


# loads definitions into pronto based on definitions in Main
macro configure(T)
    return quote
        @variables _x[1:nx(Main.$T())] _u[1:nu(Main.$T())]

        local f = Main.f
        PRONTO.f(::Main.$T,x,u) = f(x,u)

        local fx = jacobian(_x,f,_x,_u; inplace=false)
        PRONTO.fx(::Main.$T,x,u) = fx(x,u) # NX,NX #NOTE: for testing
        
    end
end


end # module


## ----------------------------------- dependencies ----------------------------------- ##

using Main.PRONTO
using Main.PRONTO: nx,nu
using Main.PRONTO: @configure




## ----------------------------------- problem setup ----------------------------------- ##

# define problem type:
NX = 2; NU = 1
struct FooSystem <: PRONTO.Model{NX,NU} end

# define: f,l,p, regulator
# fn(x,u,t,θ)
f(x,u) = collect(x)

# autodiff/model setup
@configure FooSystem

## ----------------------------------- tests ----------------------------------- ##


# run pronto
# pronto(FooSystem, α, μ, parameters...)
M = FooSystem()
x = [0,0]
u = [0]
PRONTO.f(M,x,u)
PRONTO.fx(M,x,u)


