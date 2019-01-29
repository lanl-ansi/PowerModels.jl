using Documenter, PowerModels

makedocs(
    modules = [PowerModels],
    format = :html,
    sitename = "PowerModels",
    authors = "Carleton Coffrin, Russell Bent, and contributors.",
    analytics = "UA-367975-10",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "quickguide.md",
            "Network Data Format" => "network-data.md",
            "Result Data Format" => "result-data.md",
            "Mathematical Model" => "math-model.md",
            "Storage Model" => "storage.md",
            "Multi Networks" => "multi-networks.md",
            "Utilities" => "utilities.md"
        ],
        "Library" => [
            "Network Formulations" => "formulations.md",
            "Problem Specifications" => "specifications.md",
            "Modeling Components" => [
                "PowerModel" => "model.md",
                "Objective" => "objective.md",
                "Variables" => "variables.md",
                "Constraints" => "constraints.md"
            ],
            "Relaxation Schemes" => "relaxations.md",
            "File IO" => "parser.md"
        ],
        "Developer" => [
                "Developer" => "developer.md",
                "Formulation Details" => "formulation-details.md"
        ],
        "Experiment Results" => "experiment-results.md"
    ]
)

deploydocs(
    repo = "github.com/lanl-ansi/PowerModels.jl.git",
)
