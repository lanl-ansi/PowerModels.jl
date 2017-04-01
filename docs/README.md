# Building the Documentation for PowerModels.jl

## Installation
We rely on [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl). To install it, run the following command in a julia session:

```julia
Pkg.add("Documenter")
```

## Building the Docs
To preview the html output of the documents, run the following command in this directory:

```julia
julia preview.jl
```

You can then view the documents in `build/index.html`.

For further details, please read the [documentation for Documenter.jl](https://juliadocs.github.io/Documenter.jl/stable/).