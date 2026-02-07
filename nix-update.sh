#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MSG_FILE="commit_message.txt"

function update_pkg() {
    local pkg=$1
    local tmp_msg="/tmp/nix-update.$pkg.txt"

    echo -e "${GREEN}Checking updates for $pkg...${NC}"

    nix build ".#$pkg.src"
    nix run path:third/nix-update -- -f ./. --flake "$pkg" --print-commit-message > "$tmp_msg"

    if [ -s "$tmp_msg" ] && [ -n "$(git status --porcelain)" ]; then
        echo -e "${GREEN}Update found for $pkg.${NC}"
        cat "$tmp_msg" >> "$MSG_FILE"
        echo "" >> "$MSG_FILE"
    fi
    rm -f "$tmp_msg"
}

targets=("goctl" "kratos" "trzsz" "trzsz-ssh")
# targets=("goctl")

# --- 阶段 1: 批量更新 ---
for target in "${targets[@]}"; do
    update_pkg $target
done

# --- 阶段 2: 统一格式化 ---
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${GREEN}Formatting all changes...${NC}"
    nix fmt .
fi

# --- 阶段 3: 构建验证 ---
failed_targets=()

for target in "${targets[@]}"; do
    echo "Building .#$target ..."
    nix run github:Mic92/nix-fast-build -- -f ".#ci.x86_64-linux.${target}" --skip-cached --no-nom --eval-worker 1

    if (( $? )); then
        echo -e "${RED}❌ Build failed: $target${NC}"
        failed_targets+=("$target")
    else
        echo -e "${GREEN}✅ Build success: $target${NC}"
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
