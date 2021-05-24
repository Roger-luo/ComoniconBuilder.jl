module ComoniconBuilder

using Logging
using ComoniconTypes
using ComoniconOptions
using ComoniconZSHCompletion: emit_zshcompletion
using PackageCompiler

@static if VERSION < v"1.7-"
    """
        pkgdir(m, xs...)

    Return the subdirs in given root of module `m`.
    """
    function Base.pkgdir(m::Module, x, xs...)
        dir = pkgdir(m)
        dir === nothing && return
        return joinpath(dir, x, xs...)
    end
end

include("install.jl")
include("build.jl")

end
