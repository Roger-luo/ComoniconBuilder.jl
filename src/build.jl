function build_sysimg(
    m::Module,
    options::ComoniconOptions.Comonicon;
    # allow override these two options
    incremental = options.sysimg.incremental,
    filter_stdlibs = options.sysimg.filter_stdlibs,
    cpu_target = options.sysimg.cpu_target,
)
    lib = pkgdir(m, options.sysimg.path, "lib")
    if !ispath(lib)
        @info "creating library path: $lib"
        mkpath(lib)
    end

    @info "compile under project: $(pkgdir(m))"
    @info options.sysimg

    if incremental != options.sysimg.incremental
        @info "incremental override to $incremental"
    end

    if filter_stdlibs != options.sysimg.filter_stdlibs
        @info "filter_stdlibs override to $filter_stdlibs"
    end

    if cpu_target != options.sysimg.cpu_target
        @info "cpu_target override to $cpu_target"
    end

    exec_file = map(x -> pkgdir(m, x), options.sysimg.precompile.execution_file)
    stmt_file = map(x -> pkgdir(m, x), options.sysimg.precompile.statements_file)

    create_sysimage(
        nameof(m);
        sysimage_path = joinpath(lib, PATH.sysimg(options.name)),
        incremental = incremental,
        filter_stdlibs = filter_stdlibs,
        project = pkgdir(m),
        precompile_execution_file = exec_file,
        precompile_statements_file = stmt_file,
        cpu_target = cpu_target,
    )

    return
end

function build_application(m::Module, options::ComoniconOptions.Comonicon)
    build_dir = pkgdir(m, options.application.path, options.name)
    if !ispath(build_dir)
        @info "creating build path: $build_dir"
        mkpath(build_dir)
    end

    @info "application options: " options.application

    exec_file = map(x -> pkgdir(m, x), options.application.precompile.execution_file)
    stmt_file = map(x -> pkgdir(m, x), options.application.precompile.statements_file)

    create_app(
        pkgdir(m),
        build_dir;
        app_name = options.name,
        precompile_execution_file = exec_file,
        precompile_statements_file = stmt_file,
        incremental = options.application.incremental,
        filter_stdlibs = options.application.filter_stdlibs,
        force = true,
        cpu_target = options.application.cpu_target,
        c_driver_program = get_c_driver_program(options.application),
    )

    if options.install.completion
        @info "generating completion scripts"
        build_completion(m, options)
    end
    return
end

function get_c_driver_program(options::ComoniconOptions.Application)
    default_c_driver_program = pkgdir(PackageCompiler, "src", "embedding_wrapper.c")
    return if isnothing(options.c_driver_program)
        default_c_driver_program
    else
        options.c_driver_program
    end
end


function build_tarball(m::Module, options::ComoniconOptions.Comonicon)
    build_tarball_app(m, options)
    build_tarball_sysimg(m, options)
    return
end

function build_tarball_app(m::Module, options::ComoniconOptions.Comonicon)
    isnothing(options.application) && return
    @info "building application"
    build_application(m, options)
    # pack tarball
    tarball = tarball_name(m, options.name; application = true)
    @info "creating application tarball $tarball"
    cd(pkgdir(m, options.application.path)) do
        run(`tar -czvf $tarball $(options.name)`)
    end
    return
end

function build_tarball_sysimg(m::Module, options::ComoniconOptions.Comonicon)
    isnothing(options.sysimg) && return

    @info "building system image"
    build_sysimg(m, options)
    # pack tarball
    tarball = tarball_name(m, options.name)
    @info "creating system image tarball $tarball"
    cd(pkgdir(m, options.sysimg.path)) do
        run(`tar -czvf $tarball lib`)
    end
    return
end

function download_sysimg(m::Module, options::ComoniconOptions.Comonicon)
    url = sysimg_url(m, options)
    PlatformEngines.probe_platform_engines!()

    try
        tarball = download(url)
        path = pkgdir(m, options.sysimg.path)
        unpack(tarball, path)
        # NOTE: sysimg won't be shared, so we can just remove it
        isfile(tarball) && rm(tarball)
    catch e
        @warn "fail to download $url, building the system image locally"
        # force incremental build
        build_sysimg(m, options; incremental = true, filter_stdlibs = false, cpu_target = "native")
    end
    return
end

function build_completion(m::Module, options::ComoniconOptions.Comonicon)
    completion_dir = pkgdir(m, options.application.path, options.name, "completions")
    if !ispath(completion_dir)
        @info "creating path: $completion_dir"
        mkpath(completion_dir)
    end

    for sh in ["zsh"]
        script = completion_script(sh, m)
        script === nothing && continue
        write(joinpath(completion_dir, "$sh.completion"), script)
    end
    return
end

function sysimg_url(mod::Module, options::ComoniconOptions.Comonicon)
    name = options.name
    host = options.download.host

    if host == "github.com"
        url =
            "https://github.com/" *
            options.download.user *
            "/" *
            options.download.repo *
            "/releases/download/"
    else
        error("host $host is not supported, please open an issue at $COMONICON_URL")
    end

    tarball = tarball_name(mod, name)
    url *= "v$(Comonicon.get_version(mod))/$tarball"
    return url
end


function tarball_name(m::Module, name::String; application::Bool = false)
    if application
        return "$name-application-$(get_version(m))-$(osname())-$(Sys.ARCH).tar.gz"
    else
        return "$name-sysimg-$(get_version(m))-julia-$VERSION-$(osname())-$(Sys.ARCH).tar.gz"
    end
end

"""
    osname()

Return the name of OS, will be used in building tarball.
"""
function osname()
    return Sys.isapple() ? "darwin" :
           Sys.islinux() ? "linux" :
           error("unsupported OS, please open an issue to request support at $COMONICON_URL")
end

"""
    cmd_script(mod, shadow; kwargs...)

Generates a shell script that can be use as the entry of
`mod.command_main`.

# Arguments

- `mod`: a module that contains the commands and the entry.
- `shadow`: location of a Julia script that calls the actual `mod.command_main`.

# Keywords

- `exename`: The julia executable name, default is [`PATH.default_exename`](@ref).
- `sysimg`: System image to use, default is `nothing`.
- `project`: the project path of the CLI.
- `compile`: julia compile level, can be [:yes, :no, :all, :min]
- `optimize`: julia optimization level, default is 2.
"""
function cmd_script(
    mod::Module,
    shadow::String;
    project::String = pkgdir(mod),
    exename::String = PATH.default_exename(),
    sysimg = nothing,
    compile = nothing,
    optimize = 2,
)

    head = "#!/bin/sh\n"
    if (project !== nothing) && ispath(project)
        head *= "JULIA_PROJECT=$project "
    end
    head *= exename
    script = String[head]

    if sysimg !== nothing
        push!(script, "-J$sysimg")
    end

    if compile in [:yes, :no, :all, :min]
        push!(script, "--compile=$compile")
    end

    push!(script, "-O$optimize")
    push!(script, "--startup-file=no")
    push!(script, "-- $shadow \$@")

    return join(script, " \\\n    ")
end

function completion_script(sh::String, m::Module)
    isdefined(m, :CASTED_COMMANDS) || error("cannot find Comonicon CLI entry")
    haskey(m.CASTED_COMMANDS, "main") || error("cannot find Comonicon CLI entry")
    main = m.CASTED_COMMANDS["main"]

    if sh == "zsh"
        return emit_zshcompletion(main)
    else
        @warn(
            "$sh autocompletion is not supported, " *
            "please open an issue at $COMONICON_URL for feature request."
        )
    end
    return
end

"""
    detect_shell()

Detect shell type via `SHELL` environment variable.
"""
function detect_shell()
    haskey(ENV, "SHELL") || error("cannot find available shell command")
    return basename(ENV["SHELL"])
end

function contain_comonicon_path(rcfile, env = ENV)
    if !haskey(env, "PATH")
        _contain_path(rcfile) && return true
        return false
    end

    for each in split(env["PATH"], ":")
        each == PATH.default_julia_bin() && return true
    end
    return false
end

function contain_comonicon_fpath(rcfile, env = ENV)
    if !haskey(env, "FPATH")
        _contain_fpath(rcfile) && return true
        return false
    end

    for each in split(env["FPATH"], ":")
        each == PATH.default_julia_fpath() && return true
    end
    return false
end

function _contain_path(rcfile)
    for line in readlines(rcfile)
        if strip(line) == "export PATH=\"\$HOME/.julia/bin:\$PATH\"" ||
           strip(line) == "export PATH=\"$(PATH.default_julia_bin()):\$PATH\""
            return true
        end
    end
    return false
end

function _contain_fpath(rcfile)
    for line in readlines(rcfile)
        if strip(line) == "export FPATH=\$HOME/.julia/completions:\$FPATH" ||
           strip(line) == "export FPATH=\"$(PATH.default_julia_fpath()):\$FPATH\""
            return true
        end
    end
    return false
end

function install_env_path(; yes::Bool = false)
    shell = detect_shell()

    config_file = ""
    if shell == "zsh"
        config_file = joinpath((haskey(ENV, "ZDOTDIR") ? ENV["ZDOTDIR"] : homedir()), ".zshrc")
    elseif shell == "bash"
        config_file = joinpath(homedir(), ".bashrc")
        if !isfile(config_file)
            config_file = joinpath(homedir(), ".bash_profile")
        end
    else
        @warn "auto installation for $shell is not supported, please open an issue under Comonicon.jl"
    end

    write_path(joinpath(homedir(), config_file), yes)
end

"""
    write_path(rcfile[, yes=false])

Write `PATH` and `FPATH` to current shell's rc files (.zshrc, .bashrc)
if they do not exists.
"""
function write_path(rcfile, yes::Bool = false, env = ENV)
    isempty(rcfile) && return

    script = []
    msg = "cannot detect $(PATH.default_julia_bin()) in PATH, do you want to add it in PATH?"

    if !contain_comonicon_path(rcfile, env) && prompt(msg, yes)
        push!(
            script,
            """
            # generated by Comonicon
            # Julia bin PATH
            export PATH="$(PATH.default_julia_bin()):\$PATH"
            """,
        )
        @info "adding PATH to $rcfile"
    end

    msg = "cannot detect $(PATH.default_julia_fpath()) in FPATH, do you want to add it in FPATH?"
    if !contain_comonicon_fpath(rcfile, env) && prompt(msg, yes)
        push!(
            script,
            """
            # generated by Comonicon
            # Julia autocompletion PATH
            export FPATH="$(PATH.default_julia_fpath()):\$FPATH"
            autoload -Uz compinit && compinit
            """,
        )
        @info "adding FPATH to $rcfile"
    end

    # exit if nothing to add
    isempty(script) && return
    # NOTE: we don't create the file if not exists
    open(rcfile, "a") do io
        write(io, "\n" * join(script, "\n"))
    end
    @info "open a new terminal, or source $rcfile to enable the new PATH."
    return
end
