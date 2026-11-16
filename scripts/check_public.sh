#!/bin/sh
set -eu

revision=${1:-HEAD}
if [ "$(git rev-list --count "$revision")" -ne 1 ]; then
    echo 'Public main must contain exactly one root commit. Use git commit --amend.' >&2
    exit 1
fi

# Deliberate allowlist: adding a public file requires reviewing this list too.
unexpected=$(git ls-tree -r --name-only "$revision" | LC_ALL=C grep -Ev \
    '^(\.gitignore|\.githooks/pre-push|Makefile|README\.md|Project\.toml|Manifest-v1\.12\.toml|src/PKAssetPrices\.jl|src/base\.jl|src/static/(static_model|model_macros|balance_sheets|display|curves)\.jl|src/static/models/asset_model\.jl|src/plotting/static_plotting\.jl|scripts/(produce_static_plots|produce_gamma_experiments_plots)\.jl|scripts/(check_public|publish_public)\.sh|test/(runtests|test_core|test_static|test_models|test_plotting)\.jl)$' || :)
if [ -n "$unexpected" ]; then
    printf 'Files outside the reviewed public scope:\n%s\n' "$unexpected" >&2
    exit 1
fi
