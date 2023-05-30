using PRONTO
using FastClosures
using StaticArrays
using LinearAlgebra
using MatrixEquations


NX = 2
NU = 1
NΘ = 0

struct InvPend <: PRONTO.Model{NX,NU,NΘ}
end

function dynamics(x,u,t,θ)
    g = 9.81
    L = 2
    [x[2],
    g/L*sin(x[1])-u[1]*cos(x[1])/L]
end


Rreg(x,u,t,θ) = diagm([1e-3])
Qreg(x,u,t,θ) = diagm([10, 1])

function stagecost(x,u,t,θ)
    Ql = I(NX)
    Rl = I(NU)
    1/2 * collect(x')*Ql*x + 1/2 * collect(u')*Rl*u
end

function termcost(x,u,t,θ)
    Pl = [
            88.0233 39.3414;
            39.3414 17.8531;
        ]
    1/2*collect(x')*Pl*x
end

PRONTO.generate_model(InvPend, dynamics, stagecost, termcost, Qreg, Rreg)

##

θ = InvPend()
τ = t0,tf = 0,10
x0 = @SVector [π;0]
xf = @SVector [0;0]
u0 = @SVector [0.0]
smooth(t, x0, xf, tf) = @. (xf - x0)*(tanh((2π/tf)*t - π) + 1)/2 + x0
μ = @closure t->u0*sin(t)
α = @closure t->smooth(t, x0, xf, tf)
φ = PRONTO.Trajectory(θ,α,μ);
pronto(θ,x0,φ,τ; maxiters=1000)
