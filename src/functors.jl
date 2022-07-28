# an object that allows non-allocating, type-stable returns

# Ar = Functor(model.fx, X_α, U_μ, NX, NX)
# Ar(t) updates in-place and returns SArray{T}

# Interpolation{S,T} = LinearInterpolation{Vector{SArray{S,T}}, Vector{Float64}}

struct Functor{F,T}
    fxn!::F
    buf::T
end



# B = Functor{NX,NU}( (B,t)->fu!(B, x(t), u(t)) )

function Functor(fxn!, dims::Vararg{Int})
    buf = MArray{Tuple{dims...},Float64}(undef) #FIX: generalize T beyond F64?
    T = typeof(buf)
    F = typeof(fxn!)
    Functor{F,T}(fxn!,buf)
end

function (A::Functor{F,T})(args...) where {F,T}
    A.fxn!(A.buf, args...) # in-place update
    return A.buf::T
end

Base.show(io::IO, ::Functor{F,T}) where {F,T} = print(io, "Functor of $(T)")




buffer(dims::Vararg{Int}) = MArray{Tuple{dims...},Float64}(undef)

B = buffer(NX,NU)
fu!(B, x(t), u(t))

function _B(t)
    fu!(B, x(t), u(t))
end