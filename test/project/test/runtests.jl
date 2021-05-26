using Test
using TestProject
using ComoniconOptions
using ComoniconBuilder
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

@testset "installation" begin
    install(TestProject, options)
    @test isfile(joinpath(usr_dir, "bin", "test"))
    @test isfile(joinpath(usr_dir, "bin", "test.jl"))
    rm(usr_dir; recursive=true)
end

options = ComoniconOptions.Comonicon(
    name="test",
    install=ComoniconOptions.Install(
        path=usr_dir,
    ),
    sysimg=ComoniconOptions.SysImg(;)
)

# empty!(ARGS)
# push!(ARGS, "sysimg")
# install(TestProject, options)
