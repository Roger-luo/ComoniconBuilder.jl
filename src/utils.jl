prompt(msg, yes::Bool = false) = prompt(stdin, msg, yes)

function prompt(io::IO, msg, yes::Bool = false)
    print(msg)

    if yes
        println(" Yes.")
    else
        print(" [Y/n] ")
        run(`stty raw`)
        input = read(io, Char)
        run(`stty cooked`)
        println()
        input in ['Y', 'y', '\n', '\r'] || return false
    end

    return true
end

sysimg() = "libcomonicon.$(Libdl.dlext)"
sysimg(name) = "lib$name.$(Libdl.dlext)"

"""
    default_exename()
Default Julia executable name: `joinpath(Sys.BINDIR, Base.julia_exename())`
"""
default_exename() = joinpath(Sys.BINDIR, Base.julia_exename())

dot_julia() = first(DEPOT_PATH)

"""
    default_julia_bin()
Return the default path to `.julia/bin`.
"""
default_julia_bin() = joinpath(first(DEPOT_PATH), "bin")

"""
    default_julia_fpath()
Return the default path to `.julia/completions`
"""
default_julia_fpath() = joinpath(first(DEPOT_PATH), "completions")
