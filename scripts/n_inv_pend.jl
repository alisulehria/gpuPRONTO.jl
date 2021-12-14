using LinearAlgebra
using DifferentialEquations
using GLMakie

## parameters
g = 9.8
l = 1
N = 4
m = [1, 20, 1, 1]
m = [1, 1, 1, 1]
T = t -> zeros(4)

tspan = (0.0, 10.0)
θ₀ = zeros(N)
θ₀[N] = .1
θd₀ = zeros(N)

## dynamics
# mass matrix M:
U = UpperTriangular(ones(N,N))
L = LowerTriangular(ones(N,N))
Linv = inv(L)

# ℳ =  (U * m) .* I(N)
ℳvec = (U * m) 
ℳ = [ℳvec[ max(i,j)] for i in 1:N, j in 1:N]
𝒞 = ϕ -> [cos(ϕ[i] - ϕ[j]) for i in 1:N, j in 1:N]
M = ϕ -> l^2 .* ℳ .* 𝒞(ϕ) * L

# coriolis vector C:
𝒮 = ϕ -> [sin(ϕ[i] - ϕ[j]) for i in 1:N, j in 1:N]
C = (ϕ, ϕd) -> l^2 .* ℳ .* 𝒮(ϕ) * ϕd.^2

# body force vector G:
Mtot = sum(m)
G = ϕ -> Mtot.*g.*l .* sin.(ϕ)

# ODE solver formulation:
function f!(dx, x, T, t)
    # L: θ -> ϕ, Linv: ϕ -> θ
    θ = x[1:N]; θd = x[N+1:end]
    ϕ = L * θ
    ϕd = L * θd
    θdd = inv(M(ϕ)) * (-C(ϕ, ϕd) - G(ϕ) + T(t))
    dx[1:N] = θd; dx[N+1:end] = θdd
end

## solve ODE
prob = ODEProblem(f!, [θ₀; θd₀], tspan, T)
x = solve(prob)

## simulate
time = Node(0.0)
xplot = @lift(x($time))

points = Node(Point[])
colors = Node(Int[])

# set_theme!(theme_black())

lim = N*l
fig, ax, l = lines(points, color = colors,
    colormap = :inferno, transparency = true,
    axis = (; limits = (-lim, lim, -lim, lim)))

function phi2xy(ϕ, i, l)
    x = -l*sum(sin.(ϕ[1:i]))
    y = l*sum(cos.(ϕ[1:i]))
    return 

function step!(x)
    x(t)[N] # Nth link angle
end

record(fig, "Npend.mp4", 1:120) do frame
    for i in 1:50
        push!(points[], step!(attractor))
        push!(colors[], frame)
    end
    ax.azimuth[] = 1.7pi + 0.3 * sin(2pi * frame / 120)
    notify.((points, colors))
    l.colorrange = (0, frame)
end