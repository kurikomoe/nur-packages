#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$PROJECT_DIR"
TEMP_DIR="$PROJECT_DIR/@temp"
mkdir -p "$TEMP_DIR"
export TMPDIR="$TEMP_DIR"

# Evaluate the working files against the locked nixpkgs. This also sees newly
# added package files and avoids copying ignored temporary sockets into Nix.
EVAL_FILE="$TEMP_DIR/nix-update-packages.nix"
cat > "$EVAL_FILE" <<'NIX'
{...}: let
  project = builtins.dirOf (builtins.dirOf __curPos.file);
  flake = builtins.getFlake ("git+file://" + project);
  pkgs = import flake.inputs.nixpkgs {config.allowUnfree = true;};
in
  (import (project + "/default.nix") {inherit pkgs; inherit (flake) inputs;})
  // {
    _updateNix = pkgs.nix-update;
    _updateNode = pkgs.nodejs;
    _updateFormatter = pkgs.alejandra;
  }
NIX

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MSG_FILE="commit_message.txt"

function package_file() {
    case "$1" in
        goctl|kratos) printf '%s/pkgs/%s.nix\n' "$PROJECT_DIR" "$1" ;;
        trzsz|trzsz-ssh) printf '%s/pkgs/trzsz-ssh.nix\n' "$PROJECT_DIR" ;;
        dsh|dsh-tui) printf '%s/pkgs/ai/dsh/%s.nix\n' "$PROJECT_DIR" "$1" ;;
        *) echo "Unknown update target: $1" >&2; return 2 ;;
    esac
}

function update_pkg() {
    local pkg=$1
    local pkg_file=$2
    local source_path update_log before after
    local tracked_files=("$pkg_file")
    if [ "$pkg" = dsh ]; then
        tracked_files+=("$PROJECT_DIR/pkgs/ai/dsh/package-lock.json")
    fi
    before=$(sha256sum "${tracked_files[@]}")
    update_log=$(mktemp "$TEMP_DIR/nix-update.$pkg.XXXXXX.txt")

    echo -e "${GREEN}Checking updates for $pkg...${NC}"

    # 尝试构建源码，确保网络和 hash 没问题
    source_path=$(nix build --impure --file "$EVAL_FILE" "$pkg.src" \
        --no-link --print-out-paths)

    if [ "$pkg" = dsh ]; then
        local lock_dir
        lock_dir=$(mktemp -d "$TEMP_DIR/dsh-lock.XXXXXX")
        mkdir -p "$lock_dir/source" "$lock_dir/work"
        tar -xf "$source_path" -C "$lock_dir/source"
        nix shell --impure --file "$EVAL_FILE" _updateNode --command node \
            "$PROJECT_DIR/pkgs/ai/dsh/update-lock.mjs" \
            "$lock_dir/source/package/package.json" "$lock_dir/work" "$TEMP_DIR/npm-cache"
    fi

    # 运行 nix-update
    # nvfetcher owns versions and source hashes; only update dependency hashes.
    # The override keeps nix-update from selecting _sources via inherited src.
    (
        cd "$TEMP_DIR"
        nix shell --impure --file "$EVAL_FILE" _updateNix --command nix-update \
            --file "$EVAL_FILE" --version=skip --no-src \
            --override-filename "$pkg_file" "$pkg"
    ) 2>&1 | tee "$update_log"

    after=$(sha256sum "${tracked_files[@]}")
    if [ "$before" != "$after" ]; then
        echo -e "${GREEN}Update found for $pkg.${NC}"
        printf '%s: update dependency hashes\n' "$pkg" >> "$MSG_FILE"
    fi
}

targets=("goctl" "kratos" "trzsz" "trzsz-ssh" "dsh" "dsh-tui")
if [ "$#" -gt 0 ]; then
    targets=("$@")
fi
if [[ " ${targets[*]} " == *" dsh-tui "* && " ${targets[*]} " != *" dsh "* ]]; then
    targets=("dsh" "${targets[@]}")
fi
package_files=()
for target in "${targets[@]}"; do
    package_files+=("$(package_file "$target")")
done

# --- 阶段 1: 批量更新 ---
for index in "${!targets[@]}"; do
    update_pkg "${targets[$index]}" "${package_files[$index]}"
done

# --- 阶段 2: 统一格式化 ---
echo -e "${GREEN}Formatting package files...${NC}"
mapfile -t format_files < <(printf '%s\n' "${package_files[@]}" | sort -u)
nix shell --impure --file "$EVAL_FILE" _updateFormatter --command alejandra "${format_files[@]}"

# --- 阶段 3: 构建验证 ---
failed_targets=()

for target in "${targets[@]}"; do
    echo "Building $target ..."
    if nix build --impure --file "$EVAL_FILE" "$target" --no-link -L; then
        echo -e "${GREEN}✅ Build success: $target${NC}"
    else
        echo -e "${RED}❌ Build failed: $target${NC}"
        failed_targets+=("$target")
    fi
done

if [ ${#failed_targets[@]} -ne 0 ]; then
    echo "--------------------------------"
    echo -e "${RED}The following builds failed:${NC}"
    for t in "${failed_targets[@]}"; do
        echo " - $t"
    done
    exit 1
fi

echo -e "${GREEN}All builds succeeded.${NC}"
