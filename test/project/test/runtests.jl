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
    sysimg=ComoniconOptions.SysImg(precompile=ComoniconOptions.Precompile(["deps/precompile_execution.jl"], []))
)

# empty!(ARGS)
# push!(ARGS, "sysimg")
# install(TestProject, options)

if get(ENV, "TEST_BUILD_SYSIMG", false) == "true"
    @testset "System Image building" begin
        options_sys = ComoniconOptions.Comonicon(
            name="test",
            install=ComoniconOptions.Install(
                path=usr_dir,
            ),
        sysimg=ComoniconOptions.SysImg(precompile=ComoniconOptions.Precompile(["precompile_execution.jl"], []))
    )
        outpath = ComoniconBuilder.pkgdir(TestProject, "deps/lib/libtest.so")
        
        isfile(outpath) && rm(outpath)
        ComoniconBuilder.build_sysimg(TestProject, options_sys)
        # Test if the new system image is present
        @test isfile(outpath) && isnothing(rm(outpath))
    end
end

if get(ENV, "TEST_BUILD_APP", false) == "true"
    @testset "App building" begin
        options_app = ComoniconOptions.Comonicon(
            name="test",
            install=ComoniconOptions.Install(
                path=usr_dir,
            ),
        application=ComoniconOptions.Application(
            precompile=ComoniconOptions.Precompile(["precompile_execution.jl"], []),
            incremental=true,
            filter_stdlibs=false,
            )
    )
        outpath = ComoniconBuilder.pkgdir(TestProject, "build/test/bin/test")

        isfile(outpath) && rm(outpath)
        ComoniconBuilder.build_application(TestProject, options_app)
        # Test if the app has been built
        @test isfile(outpath) && isnothing(rm(outpath))
    end
end
