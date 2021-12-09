
function optKr(A,B,Q,R)
    # create optimal LQ regulator Kr that stabilizes around trajectory
    P = solve_diff_ric(A,B,Q,R)# call riccati solver
    Kᵣ = inv(R)*B'*P
end

function ẋl!((ẋ, l̇), (x, l), (f, ξ, Kᵣ, ḣ), t)
    u = ξ.u(t) + Kᵣ(t) * (ξ.x(t) - x)
    ẋ = f(x, u)
    l̇ = ḣ(x, u)
end

project_u(ξ, x, Kᵣ) = (t) -> ξ.u(t) + Kᵣ(t) * (ξ.x(t) - x(t))

function project(ξ, f, Kᵣ, ḣ, T)
    # project desired curve onto trajectory manifold using Kr
    p = (f, ξ, Kᵣ, ḣ)
    prob = ODEProblem(ẋl!, (ξ.x(0), 0), (0,T), p) # IC syntax?
    x,l = solve(prob) # output syntax?
    u = project_u(ξ, x, Kᵣ)
    return Trajectory(x, u), l
end

function armijo_step(ξ, ζ, g, Dh, (α, β)=(.7,.4))
    while γ > .01 # TODO: make min β a parameter?
        true_cost = g(ξ + γ*ζ)
        threshold =  α*Dh(ξ, γ*ζ) # maybe a clever way to def as α*Dh(ξ) /dot γ*ζ 
        true_cost < threshold ? (return γ) : (γ *= β)
    end
    γ = 0
end

function pronto()
    A,B = linearize() 
    Kᵣ = optKr(A,B,Q,R)
    ξ, l = project(ξ, f, Kᵣ, ḣ, T) # make mutating?
    while γ > 0 # if keep γ as only condition, move initialization into loop?
        ζ = search_direction()
        γ = stepsize(ξ) #TODO: move into search_direction? then can check posdef q
        ξ = ξ + γ*ζ
        ξ, l = project(ξ, f, Kᵣ, ḣ, T)
        Kᵣ = optKr(A,B,Q,R)
    end
    return ξ, Kᵣ
end