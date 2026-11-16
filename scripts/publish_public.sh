#!/bin/sh
set -eu

if [ "$(git symbolic-ref --quiet --short HEAD)" != main ]; then
    echo 'Switch to the public main branch before publishing.' >&2
    exit 1
fi
sh scripts/check_public.sh HEAD
if ! git diff --quiet; then
    echo 'Stage all intended tracked-file changes with git add before publishing.' >&2
    exit 1
fi

# An explicit lease prevents overwriting another maintainer's intervening update.
public_url=https://github.com/theplatters/PKAssetPrices.git
git fetch --no-tags "$public_url" refs/heads/main
expected=$(git rev-parse FETCH_HEAD)
if [ "$(git rev-parse HEAD)" != "$expected" ]; then
    echo 'Local main differs from public main. Review the remote update before amending.' >&2
    exit 1
fi
if ! git diff --cached --quiet; then
    git commit --amend --no-edit
fi
sh scripts/check_public.sh HEAD
git push --force-with-lease="refs/heads/main:$expected" "$public_url" HEAD:refs/heads/main
