using ComoniconOptions
using ComoniconBuilder
using Test
using ComoniconBuilder: install, install_script, install_completion,
    cmd_script, contains_path, contains_fpath, write_path, write_fpath, detect_rcfile,
    install_env_path

home_dir = mktempdir()
test_dir = pkgdir(ComoniconBuilder, "test")
usr_dir = joinpath(test_dir, "usr")

options = ComoniconOptions.Comonicon(
    name="test",
    install=ComoniconOptions.Install(
        path=usr_dir,
        completion=false,
    ),
    sysimg=nothing,
)

module Foo
using ComoniconTestUtils
const CASTED_COMMANDS = Dict{String, Any}(
    "main" => rand_command()
)
end

@testset "cmd script" begin
    sysimg = joinpath(options.install.path, "lib", ComoniconBuilder.sysimg("test"))
    entry_script = cmd_script(
        Foo,
        joinpath(options.install.path, "bin", "test.jl");
        project=joinpath(options.install.path, "test"),
        compile=:min,
        sysimg
    )

    @test occursin("#!/bin/sh", entry_script)
    @test occursin(ComoniconBuilder.default_exename(), entry_script)
    @test occursin("-O2", entry_script)
    @test occursin("-startup-file=no", entry_script)
    @test occursin("--compile=min", entry_script)
    @test occursin("-J$sysimg", entry_script)
    @test occursin(joinpath(options.install.path, "bin", "test.jl"), entry_script)
end

@testset "detect_shell" begin
    withenv("SHELL"=>"zsh") do
        @test ComoniconBuilder.detect_shell() == ENV["SHELL"]
    end
end

@testset "contains path/write path" begin
    withenv("PATH"=>nothing, "FPATH"=>nothing) do
        dir = mktempdir()
        rcfile = joinpath(dir, ".bashrc")
        touch(rcfile)
        @test contains_path(rcfile, usr_dir, Base.EnvDict()) == false

        write_path(rcfile, usr_dir)
        @test contains_path(rcfile, usr_dir) == true

        @test contains_fpath(rcfile, usr_dir, Base.EnvDict()) == false

        write_fpath(rcfile, usr_dir)
        @test contains_fpath(rcfile, usr_dir) == true
    end

    withenv("PATH"=>joinpath(usr_dir, "bin"), "FPATH"=>joinpath(usr_dir, "completions")) do
        @test contains_path("rcfile", usr_dir) == true
        @test contains_fpath("rcfile", usr_dir) == true
    end
end

@testset "detect rcfile" begin
    @test detect_rcfile("zsh", home_dir) == joinpath(home_dir, ".zshrc")
    @test withenv("ZDOTDIR"=>"test") do
        detect_rcfile("zsh", home_dir)
    end == joinpath("test", ".zshrc")

    @test detect_rcfile("bash", home_dir) == joinpath(home_dir, ".bash_profile")
    touch(joinpath(home_dir, ".bashrc"))
    @test detect_rcfile("bash", home_dir) == joinpath(home_dir, ".bashrc")
end

@testset "install env path" begin
    install_env_path(usr_dir, "zsh", home_dir, ENV, true)

    withenv("PATH"=>nothing, "FPATH"=>nothing) do
        @test contains_path(joinpath(home_dir, ".zshrc"), usr_dir)
        @test contains_fpath(joinpath(home_dir, ".zshrc"), usr_dir)
    end
end

@testset "install completion" begin
    install_completion(Foo, options, "zsh")
    @test isfile(joinpath(usr_dir, "completions", "_test"))
    rm(usr_dir; recursive=true)
end

@testset "install script" begin
    install_script(Foo, options; project=joinpath(options.install.path, "test"))
    @test isfile(joinpath(usr_dir, "bin", "test"))
    @test isfile(joinpath(usr_dir, "bin", "test.jl"))
    rm(usr_dir; recursive=true)    
end
