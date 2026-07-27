# Repository Guidelines

## Project Structure & Module Organization

`src/PKAssetPrices.jl` is the package entry point. Core code is grouped by concern: `src/static/` contains equilibrium models and balance-sheet helpers, `src/dynamic/` contains time-dependent models and macros, `src/dash/` implements the Dash interface, and `src/plotting/` holds plotting utilities. Optimization experiments live in `src/optim/`. Use `scripts/` for reproducible batch tasks, `notebooks/` for exploration, and `notebooks/archive/` only for historical work. Paper sources and references are in `paper/`; generated images and animations belong in `plots/`.

## Build, Test, and Development Commands

Use Julia 1.12 (the version recorded in `Manifest.toml`) from the repository root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using PKAssetPrices'
julia --project=. src/dash.jl
typst compile paper/main.typ paper/main.pdf
```

The first command installs pinned dependencies; the second is a fast package-load smoke test. The third starts the local dashboard. The final command rebuilds the Typst paper when documentation changes. Commit `Project.toml` and `Manifest.toml` together when dependencies change; do not edit the manifest manually.

## Coding Style & Naming Conventions

Follow standard Julia conventions: four-space indentation, `snake_case` for functions and variables, `CamelCase` for types and modules, and a trailing `!` for mutating functions. Keep model definitions near their domain (`src/static/models/` or `src/dynamic/models/`) and add new includes to the relevant module file. Unicode mathematical identifiers such as `α` are acceptable where they mirror equations, but prefer descriptive ASCII names for infrastructure code. No formatter is configured, so keep diffs focused and match neighboring style.

## Testing Guidelines

Tests live in `test/` and use Julia's `Test` standard library. Run the complete suite with `julia --project=. -e 'using Pkg; Pkg.test()'`, or run `julia --project=. test/runtests.jl` while iterating in the active environment. Place focused coverage in files named `test_<feature>.jl` and include them from `test/runtests.jl`. Keep numerical residual assertions tolerant to floating-point error, and add regression coverage for affected model solves, curves, dashboard components, or lag behavior.

## Commit & Pull Request Guidelines

History uses brief, topic-focused subjects (for example, `correction Table2` and `update paper`). Prefer an imperative summary under 72 characters; optional prefixes such as `feat:` are acceptable. Pull requests should explain the economic or technical change, list validation commands, link related issues, and include screenshots for dashboard or plot changes. Avoid committing transient notebook outputs or generated media unless they are intentional review artifacts.
