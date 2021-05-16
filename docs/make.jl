using ComoniconBuilder
using Documenter

DocMeta.setdocmeta!(ComoniconBuilder, :DocTestSetup, :(using ComoniconBuilder); recursive=true)

makedocs(;
    modules=[ComoniconBuilder],
    authors="Roger-Luo <rogerluo.rl18@gmail.com> and contributors",
    repo="https://github.com/Roger-luo/ComoniconBuilder.jl/blob/{commit}{path}#{line}",
    sitename="ComoniconBuilder.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Roger-luo.github.io/ComoniconBuilder.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Roger-luo/ComoniconBuilder.jl",
)
