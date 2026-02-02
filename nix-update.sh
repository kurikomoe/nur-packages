#!/usr/bin/env bash

set -e

function update_pkg() {
    nix eval ".#ci.x86_64-linux.$1"
    nix run path:third/nix-update -- -f ./. --commit --flake $1
}

targets=("goctl" "kratos" "trzsz" "trzsz-ssh")

for target in "${targets[@]}"; do
    update_pkg $target
done

failed_targets=()

for target in "${targets[@]}"; do
    echo "Building .#$target ..."
    nix run github:Mic92/nix-fast-build -- -f ".#ci.x86_64-linux.${target}" --skip-cached --no-nom --eval-worker 1
    rc=$?
    if (( rc )); then
        echo "❌ Build failed: $target"
        failed_targets+=("$target")
    else
        echo "✅ Build success: $target"
    fi
done

if [ ${#failed_targets[@]} -ne 0 ]; then
    echo "--------------------------------"
    echo "The following builds failed:"
    for t in "${failed_targets[@]}"; do
        echo " - $t"
    done
    exit 1
else
    echo "All builds succeeded."
    exit 0
fi

