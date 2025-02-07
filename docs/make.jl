using Documenter
using Literate
using JuMP
const MathOptInterface = MOI
using Test

# When updating the version of MOI used to build these docs, change the entry in
# Project.toml, and modify the info message below. You may need to modify the
# JuMP documentation to avoid conflicts with the header links (i.e., JuMP and
# MOI both have a header called `# Foo`, then `[Foo](@ref)` doesn't know which
# to link to).
const _INCLUDE_MOI = true
const _MOI_INFO_MSG = """
!!! info
    This documentation is a copy of the official MathOptInterface documentation
    available at [https://jump.dev/MathOptInterface.jl/v0.10.3](https://jump.dev/MathOptInterface.jl/v0.10.3).
    It is included here to make it easier to link concepts between JuMP and
    MathOptInterface.

"""

# Pass --fast as an argument to skip rebuilding the examples and running
# doctests. Only use this argument to rapidly test small changes to the
# Markdown. _Never_ set it in production.
const _FAST = findfirst(isequal("--fast"), ARGS) !== nothing

const _TUTORIAL_DIR = joinpath(@__DIR__, "src", "tutorials")
const _TUTORIAL_SUBDIR = [
    "Getting started",
    "Mixed-integer linear programs",
    "Nonlinear programs",
    "Quadratic programs",
    "Conic programs",
    "Semidefinite programs",
    "Optimization concepts",
]

function link_example(content)
    edit_url = match(r"EditURL = \"(.+?)\"", content)[1]
    footer = match(r"^(---\n\n\*This page was generated using)"m, content)[1]
    content = replace(
        content,
        footer => "[View this file on Github]($(edit_url)).\n\n" * footer,
    )
    return content
end

function _file_list(full_dir, relative_dir, extension)
    return map(
        file -> joinpath(relative_dir, file),
        filter(file -> endswith(file, extension), sort(readdir(full_dir))),
    )
end

"""
    _include_sandbox(filename)

Include the `filename` in a temporary module that acts as a sandbox. (Ensuring
no constants or functions leak into other files.)
"""
function _include_sandbox(filename)
    mod = @eval module $(gensym()) end
    return Base.include(mod, filename)
end

function literate_directory(dir)
    rm.(_file_list(dir, dir, ".md"))
    for filename in _file_list(dir, dir, ".jl")
        # `include` the file to test it before `#src` lines are removed. It is
        # in a testset to isolate local variables between files.
        @testset "$(filename)" begin
            _include_sandbox(filename)
        end
        Literate.markdown(
            filename,
            dir;
            documenter = true,
            postprocess = link_example,
        )
    end
    return nothing
end

if !_FAST
    literate_directory.(joinpath.(_TUTORIAL_DIR, _TUTORIAL_SUBDIR))
end

const _PAGES = [
    "Introduction" => "index.md",
    "installation.md",
    "Tutorials" => map(
        subdir ->
            subdir => map(
                file -> joinpath("tutorials", subdir, file),
                filter(
                    file -> endswith(file, ".md"),
                    sort(readdir(joinpath(_TUTORIAL_DIR, subdir))),
                ),
            ),
        _TUTORIAL_SUBDIR,
    ),
    "Manual" => [
        "manual/models.md",
        "manual/variables.md",
        "manual/expressions.md",
        "manual/objective.md",
        "manual/constraints.md",
        "manual/containers.md",
        "manual/solutions.md",
        "manual/nlp.md",
        "manual/callbacks.md",
    ],
    "API Reference" => [
        "reference/models.md",
        "reference/variables.md",
        "reference/expressions.md",
        "reference/objectives.md",
        "reference/constraints.md",
        "reference/containers.md",
        "reference/solutions.md",
        "reference/nlp.md",
        "reference/callbacks.md",
        "reference/extensions.md",
    ],
    "Background information" => [
        "background/should_i_use.md",
        "background/algebraic_modeling_languages.md",
    ],
    "Developer Docs" => [
        "Contributing" => "developers/contributing.md",
        "Extensions" => "developers/extensions.md",
        "Style Guide" => "developers/style.md",
        "Roadmap" => "developers/roadmap.md",
    ],
    "Release notes" => "release_notes.md",
]

function _add_moi_pages()
    moi_docs = joinpath(dirname(dirname(pathof(MOI))), "docs")
    cp(
        joinpath(moi_docs, "src"),
        joinpath(@__DIR__, "src", "moi");
        force = true,
    )
    # Files in `moi_docs` are probably in read-only mode (`0o444`). Let's give
    # ourselves write permission.
    chmod(joinpath(@__DIR__, "src", "moi"), 0o777; recursive = true)
    make = read(joinpath(moi_docs, "make.jl"), String)
    s = match(r"pages = (\[.+?)\)"s, make)[1]
    s = strip(s)
    if endswith(s, ",")
        s = s[1:end-1]
    end
    for m in eachmatch(r"\"([a-zA-Z\_\/]+?\.md)\"", s)
        s = replace(s, m[1] => "moi/" * m[1])
    end
    push!(_PAGES, "MathOptInterface" => eval(Meta.parse(s)))
    for (root, _, files) in walkdir(joinpath(@__DIR__, "src", "moi"))
        for f in filter(f -> endswith(f, ".md"), files)
            data = read(joinpath(root, f), String)
            write(joinpath(root, f), _MOI_INFO_MSG * data)
        end
    end
    return
end

try
    rm(joinpath(@__DIR__, "src", "moi"); recursive = true)
catch
end

if _INCLUDE_MOI
    _add_moi_pages()
end

makedocs(
    sitename = "JuMP",
    authors = "Miles Lubin, Iain Dunning, and Joey Huchette",
    format = Documenter.HTML(
        # See https://github.com/JuliaDocs/Documenter.jl/issues/868
        prettyurls = get(ENV, "CI", nothing) == "true",
        analytics = "UA-44252521-1",
        collapselevel = 1,
        assets = ["assets/extra_styles.css"],
        sidebar_sitename = false,
    ),
    # `strict = true` causes Documenter to throw an error if the Doctests fail.
    strict = true,
    # ==========================================================================
    # `modules = [JuMP]`, along with `checkdocs = :exports` causes Documenter to
    # throw an error if exported functions with docstrings are not contained in
    # the Documentation. However, problematically, we include some MOI docs,
    # which forces us to include MOI in `modules`, despite the fact that we
    # don't necessarily want to document every MOI method.
    #
    # This is should be fine for now, because MOI doesn't export anything.
    # However, also problematically, some doctests in MOI are not checked and
    # are failing. Until they are fixed, we can't enable these options.
    #
    # TODO(odow): uncomment when possible.
    # modules = [JuMP, MOI],
    # checkdocs = :exports,
    # ==========================================================================
    # Skip doctests if --fast provided.
    doctest = !_FAST,
    pages = _PAGES,
)

deploydocs(repo = "github.com/jump-dev/JuMP.jl.git", push_preview = true)
