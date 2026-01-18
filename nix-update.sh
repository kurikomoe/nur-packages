#!/usr/bin/env bash

set -e

# nix-update --flake goctl &
# nix-update --flake kratos &
# nix-update --flake trzsz &
# nix-update --flake trzsz-ssh &


targets=("goctl" "kratos" "trzsz" "trzsz-ssh")
failed_targets=()

for target in "${targets[@]}"; do
    echo "Building .#$target ..."
    if ! nix build ".#$target"; then
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

