# assume A,B, Q, R, x(t), xd(t), u(t), ud(t), f, Kᵣ

# calculate a,b

a = t -> Q*(x(t)-xd(t)) #TODO: l_x'
b = t -> R*(u(t)-ud(t)) #TODO: l_u'

function qstep!(q̇, q, (Kᵣ,a,b), t)
    q̇ .= -(A(t) - B(t)*Kᵣ)'q - a(t) + Kᵣ*b(t)
end

# q(T) = r₁
q = solve(ODEProblem(qstep!, r₁, (T,0), (Kᵣ,a,b)))

# calculate R₀,S₀,Q₀
Q₀ = t -> Q(t) + sum(map((qk,fk) -> qk*fk, q(t), fxx(t)))
R₀ = t -> R(t) + sum(map((qk,fk) -> qk*fk, q(t), fuu(t)))
S₀ = t ->        sum(map((qk,fk) -> qk*fk, q(t), fxu(t)))


function backstep!((Ṗ,ṙ), (P,r), p, t)
    (a,b,R₀,S₀,Q₀,A,B) = p

    K₀ = inv(R₀(t))*(S₀(t)' + B(t)'P) # instantaneous P
    Ṗ .= -A(t)'P - P*A(t) + K₀'R₀(t)K₀ + Q₀
    ṙ .= -(A(t)-B(t)K₀)'r - a(t) + K₀*b(t)
end


P₁,_ = arec(A(T), B(T), R₀(T), Q₀(T), S₀(T))
r₁ = P₁*(x(T)-xd(T))

P,r = solve(ODEProblem(backstep!, (P₁,r₁), (T,0), params))

K₀ = t -> inv(R₀(t))(S₀(t)' + B(t)'P(t)) # P is a function of time
v₀ = t -> -inv(R₀(t))(B(t)'r(t) + b(t))

function frontstep!(ż, z, (A,B,K₀,v₀), t)
    v = -K₀(t)z + v₀(t)
    ż .= A(t)z + B(t)v
end

z = solve(ODEProblem(frontstep!, 0, (0,T), params))

#TODO: zn+1 and zn+2 outside

# function search_direction(ξ, ξd, f, Kᵣ, Q, R)
#     a = (t)->Q*(x(t)-xd(t)) # TODO: change to lx'
#     b = (t)->R*(u(t)-ud(t)) # TODO: change to lu'
#     q = solve(ODEProblem(qstep!, ))

    
# end
