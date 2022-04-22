module PRONTO
# __precompile__(false)
using LinearAlgebra
using DataInterpolations
using Symbolics
using Symbolics: derivative
using DifferentialEquations
using DataInterpolations
# using ControlSystems # provides lqr
using MatrixEquations # provides arec




include("timeseries.jl")
export Timeseries


include("autodiff.jl")
# export jacobian
# export hessian
#TODO: build pronto model

# t
# R,Q (for regulator)
# x0 (for projection)
# f,fx,fu
# fxx,fxu,fuu
# ...
# solver kw


include("regulator.jl")
# export regulator



include("projection.jl")
# export project!, projection

include("cost.jl")


#=




# helper functions
tau(f, t) = LinearInterpolation(hcat(map(f, t)...), t)




include("search_direction.jl")
# gradient_descent
# 



# armijo_backstep:
function armijo_backstep(x,u,t,z,v,Kr,x0,f,l,p,Dh)
    γ = 1
    aβ=0.7
    aα=0.4
    T = last(t)

    # compute cost
    J = cost(x,u,t,l)
    h = J(T)[1] + p(x(T))
    

    while γ > aβ^12
        # generate estimate
        α = PRONTO.tau(t->(x(t) + γ*z(t)), t);
        μ = PRONTO.tau(t->(u(t) + γ*v(t)), t);
        X2,U2 = projection(α, μ, t, Kr, x0, f);

        J = cost(X2,U2,t,l)
        g = J(T)[1] + p(X2(T))

        # check armijo rule
        println("γ=$γ, h-g=$(h-g)")
        h-g >= -aα*γ*Dh ? break : (γ *= aβ)
    end

    return γ
end


=#

end # module
