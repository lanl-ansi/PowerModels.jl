using Documenter, PowerModels

makedocs(
    modules = [PowerModels],
    format = :html,
    sitename = "PowerModels",
    pages = [
        "Home" => "index.md",
        "Getting Started" => "example.md",
        "Data Formats" => "data.md",
        "File IO" => "parser.md",
        "Network Formulations" => "formulations.md",
        "Problem Specifications" => "specifications.md",
        "Model Components" => [
            "Objective" => "objective.md",
            "Variables" => "variables.md",
            "Constraints" => "constraints.md"
        ],
        "Relaxation Schemes" => "relaxations.md"
    ]
)

# deploydocs(
#     deps = Deps.pip("pygments", "mkdocs", "mkdocs-material", "python-markdown-math"),
#     repo = "https://github.com/lanl-ansi/PowerModels.jl.git",
#     julia = "0.5"
# )