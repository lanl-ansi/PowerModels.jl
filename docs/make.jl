import Documenter
using PowerModels

Documenter.makedocs(
    sitename = "PowerModels",
    authors = "Carleton Coffrin, Russell Bent, and contributors.",
    format = Documenter.HTML(analytics = "UA-367975-10", mathengine = Documenter.MathJax()),
    modules = [PowerModels],
    # There are a large number of exported functions in PowerModels.jl that have
    # docstrings, but which are not explicitly included in the docs.
    #
    # When this is fixed, we should change to `checkdocs = :exports,`
    checkdocs = :none,
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "quickguide.md",
            "Network Data Format" => "network-data.md",
            "Result Data Format" => "result-data.md",
            "Mathematical Model" => "math-model.md",
            "Power Flow" => "power-flow.md",
            "Storage Model" => "storage.md",
            "Switch Model" => "switch.md",
            "Multi Networks" => "multi-networks.md",
            "Utilities" => "utilities.md",
            "Basic Data Utilities" => "basic-data-utilities.md"
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

Documenter.deploydocs(
    repo = "github.com/lanl-ansi/PowerModels.jl.git",
)
