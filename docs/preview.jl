using Documenter, PowerModels

makedocs(
    modules = [PowerModels],
    format = :html,
    sitename = "PowerModels",
    pages = [
        "Home" => "index.md",
        "Getting Started" => "example.md",
        "Data Formats" => "data.md",
        "Power Models" => "models.md",
        "Constraint Templates" => "constraint_templates.md"
    ]
)

# deploydocs(
#     deps = Deps.pip("pygments", "mkdocs", "mkdocs-material", "python-markdown-math"),
#     repo = "https://github.com/lanl-ansi/PowerModels.jl.git",
#     julia = "0.5"
# )