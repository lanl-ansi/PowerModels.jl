using Documenter, PowerModels

makedocs(
    modules = [PowerModels],
    format = :html,
    sitename = "PowerModels",
    pages = [
        "Home" => "index.md",
        "Getting Started" => "quickguide.md",
        "Network Formulations" => "formulations.md",
        "Problem Specifications" => "specifications.md",
        "Model Components" => [
            "Objective" => "objective.md",
            "Variables" => "variables.md",
            "Constraints" => "constraints.md"
        ],
        "Relaxation Schemes" => "relaxations.md",
        "File IO" => "parser.md",
        "Data Formats" => "data.md",
    ]
)

deploydocs(
    deps = nothing,
    make = nothing,
    target = "build",
    repo = "https://github.com/lanl-ansi/PowerModels.jl.git",
    julia = "0.5"
)
