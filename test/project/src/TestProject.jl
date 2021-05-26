module TestProject

using ComoniconTypes

const CASTED_COMMANDS = Dict(
    "main" => Entry(;
        version=v"1.2.0",
        root=LeafCommand(;
            fn=sin,
            name="sin",
            args=Argument[
                Argument(;name="x", type=Float64),
            ]
        )
    )
)

end
