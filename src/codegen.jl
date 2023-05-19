# the tools for automatically building model derivatives

using Base: invokelatest
using MacroTools: striplines, prettify, postwalk, @capture

global format::Function = identity

# builds buffered versions by default, for an in-place version, use:
struct InPlace end

export generate_model, InPlace
export build

#FUTURE: options to make pretty (or add other postprocessing), save to file, etc.
function generate_model(T, user_f, user_l, user_p, user_Q, user_R)
    info("generating the $(as_bold(T)) model")
    iinfo("initializing symbolics...")
    NX = nx(T); NU = nu(T)
    @variables x[1:NX] u[1:NU] t λ[1:NX]
    x = collect(x)
    u = collect(u)
    t = t
    θ = SymbolicModel(T)
    λ = collect(λ)

    Jx,Ju = Jacobian.([x,u])

    iinfo("tracing functions for $T...")
    f = invokelatest(user_f, x, u, t, θ)
    l = invokelatest(user_l, x, u, t, θ)
    p = invokelatest(user_p, x, u, t, θ)
    Q = invokelatest(user_Q, x, u, t, θ)
    R = invokelatest(user_R, x, u, t, θ)

    build(InPlace(), :(f!(out,x,u,t,θ::$T)), f)

    build(Size(NX,NX), :(Q(x,u,t,θ::$T)), Q)
    build(Size(NU,NU), :(R(x,u,t,θ::$T)), R)

    fx = Jx(f)
    fu = Ju(f)

    build(Size(NX), :(f(x,u,t,θ::$T)), f)
    build(Size(NX,NX), :(fx(x,u,t,θ::$T)), fx)
    build(Size(NX,NU), :(fu(x,u,t,θ::$T)), fu)

    lx = reshape(Jx(l),NX)
    lu = reshape(Ju(l),NU)

    build(Size(1), :(l(x,u,t,θ::$T)), l)
    build(Size(NX), :(lx(x,u,t,θ::$T)), lx)
    build(Size(NU), :(lu(x,u,t,θ::$T)), lu)

    lxx = Jx(lx)
    lxu = Ju(lx)
    luu = Ju(lu)

    build(Size(NX,NX), :(lxx(x,u,t,θ::$T)), lxx)
    build(Size(NX,NU), :(lxu(x,u,t,θ::$T)), lxu)
    build(Size(NU,NU), :(luu(x,u,t,θ::$T)), luu)

    fxx = Jx(Jx(f))
    fxu = Ju(Jx(f))
    fuu = Ju(Ju(f))

    #YO: can reload defs from inplace versions
    Lxx = lxx .+ sum(λ[k]*fxx[k,:,:] for k in 1:NX)
    Lxu = lxu .+ sum(λ[k]*fxu[k,:,:] for k in 1:NX)
    Luu = luu .+ sum(λ[k]*fuu[k,:,:] for k in 1:NX)

    build(Size(NX,NX), :(Lxx(λ,x,u,t,θ::$T)), Lxx)
    build(Size(NX,NU), :(Lxu(λ,x,u,t,θ::$T)), Lxu)
    build(Size(NU,NU), :(Luu(λ,x,u,t,θ::$T)), Luu)

    px = reshape(Jx(p),NX)

    build(Size(1), :(p(x,u,t,θ::$T)), p)
    build(Size(NX), :(px(x,u,t,θ::$T)), px)
    build(Size(NX,NX), :(pxx(x,u,t,θ::$T)), Jx(px))
    iinfo("done!")
    nothing
end

function init_syms(T)
    NX = nx(T)
    NU = nu(T)
    @variables x[1:NX] u[1:NU] t λ[1:NX]
    x = collect(x)
    u = collect(u)
    t = t
    θ = SymbolicModel(T)
    λ = collect(λ)
    Jx,Ju = Jacobian.([x,u])
    return (NX,NU,x,u,t,θ,λ,Jx,Ju)
end

#FUTURE: options to make pretty (or add other postprocessing), save to file, etc.
function build_f(T, user_f)
    info("building dynamics methods for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    f = invokelatest(user_f, x, u, t, θ)

    build(InPlace(), :(f!(out,x,u,t,θ::$T)), f)
    build(Size(NX), :(f(x,u,t,θ::$T)), f)

    build(Size(NX,NX), :(fx(x,u,t,θ::$T)), Jx(f))
    build(Size(NX,NU), :(fu(x,u,t,θ::$T)), Ju(f))
    return nothing
end

function build_l(T, user_l)
    info("building stage cost methods for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    l = invokelatest(user_l, x, u, t, θ)
    lx = reshape(Jx(l), NX)
    lu = reshape(Ju(l), NU)

    build(Size(1), :(l(x,u,t,θ::$T)), l)
    build(Size(NX), :(lx(x,u,t,θ::$T)), lx)
    build(Size(NU), :(lu(x,u,t,θ::$T)), lu)

    build(Size(NX,NX), :(lxx(x,u,t,θ::$T)), Jx(lx))
    build(Size(NX,NU), :(lxu(x,u,t,θ::$T)), Ju(lx))
    build(Size(NU,NU), :(luu(x,u,t,θ::$T)), Ju(lu))
    return nothing
end

function build_p(T, user_p)
    info("building terminal cost methods for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    p = invokelatest(user_p, x, u, t, θ)
    px = reshape(Jx(p), NX)

    build(Size(1), :(p(x,u,t,θ::$T)), p)
    build(Size(NX), :(px(x,u,t,θ::$T)), px)
    build(Size(NX,NX), :(pxx(x,u,t,θ::$T)), Jx(px))
    return nothing
end

function build_Q(T, user_Q)
    info("building regulator Q method for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    Q = invokelatest(user_Q, x, u, t, θ)
    build(Size(NX,NX), :(Q(x,u,t,θ::$T)), Q)
    return nothing
end

function build_R(T, user_R)
    info("building regulator R method for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    R = invokelatest(user_R, x, u, t, θ)
    build(Size(NU,NU), :(R(x,u,t,θ::$T)), R)
    return nothing
end

function build_L(T, user_R)
    info("building lagrangian methods for $(as_bold(T))")
    NX,NU,x,u,t,θ,λ,Jx,Ju = init_syms(T)

    # invokelatest(lxx())

    
    #YO: can reload defs from inplace versions
    Lxx = lxx .+ sum(λ[k]*fxx[k,:,:] for k in 1:NX)
    Lxu = lxu .+ sum(λ[k]*fxu[k,:,:] for k in 1:NX)
    Luu = luu .+ sum(λ[k]*fuu[k,:,:] for k in 1:NX)

    build(Size(NX,NX), :(Lxx(λ,x,u,t,θ::$T)), Lxx)
    build(Size(NX,NU), :(Lxu(λ,x,u,t,θ::$T)), Lxu)
    build(Size(NU,NU), :(Luu(λ,x,u,t,θ::$T)), Luu)
end

# append ! to a symbol, eg. :name -> :name!
_!(ex) = Symbol(String(ex)*"!")


# eg. Jx = Jacobian(x); fx_sym = Jx(f_sym)
# maps symbolic -> symbolic
struct Jacobian dv end

function (J::Jacobian)(f_sym)
    fv_sym = map(1:length(J.dv)) do i
        map(f_sym) do f
            derivative(f, J.dv[i])
        end
    end
    return cat(fv_sym...; dims=ndims(f_sym)+1) #ndims = 0 for scalar-valued l,p
end
# isnothing(force_dims) || (fx_sym = reshape(fx_sym, force_dims...))


MType(sz::Size{S}) where {S} = MType(Val(length(S)), sz)
MType(::Val{1}, sz::Size{S}) where {S} = MVector{S..., Float64}
MType(::Val{2}, sz::Size{S}) where {S} = MMatrix{S..., Float64}
MType(::Val, sz::Size{S}) where {S} = MArray{Tuple{S...}, Float64, length(S), prod(S)}

SType(sz::Size{S}) where {S} = SType(Val(length(S)), sz)
SType(::Val{1}, sz::Size{S}) where {S} = SVector{S..., Float64}
SType(::Val{2}, sz::Size{S}) where {S} = SMatrix{S..., Float64}
SType(::Val, sz::Size{S}) where {S} = SArray{Tuple{S...}, Float64, length(S), prod(S)}


#MAYBE: do we actually want to save the whole model to a file?
function build(sz, hdr, sym; file=nothing)
    body = tmap(enumerate(sym)) do (i,x)
        :(out[$i] = $(format(toexpr(x))))
    end
    @capture(hdr, name_(args__))
    ex = _build(sz, name, args, body)
    file = tempname()*".jl"
    write(file, string(clean(ex)))
    Base.include(Main, file)
    iinfo("$hdr\t"*as_color(crayon"dark_gray", "[$file]"))
    # eval(ex)
end

function _build(sz::Size, name, args, body)
    quote
        function PRONTO.$name($(args...))
            out = $(MType(sz))(undef)
            @inbounds begin
                $(body...)
            end
            return $(SType(sz))(out)
        end
    end
end

function _build(::InPlace, name, args, body)
    quote
        function PRONTO.$name($(args...))
            @inbounds begin
                $(body...)
            end
            return nothing
        end
    end
end


# make a version of v with the sparsity pattern of fn
function sparse_mask(v, fn)
    v .* map(fn) do ex
        iszero(ex) ? 0 : 1
    end |> collect
end


# remove excess begin blocks & comments
function clean(ex)
    postwalk(striplines(ex)) do ex
        isexpr(ex) && ex.head == :block && length(ex.args) == 1 ? ex.args[1] : ex
    end
end


# insert the `new` expression at each matching `tgt` in the `src`
function crispr(src,tgt,new)
    postwalk(src) do ex
        return @capture(ex, $tgt) ? new : ex
    end
end
