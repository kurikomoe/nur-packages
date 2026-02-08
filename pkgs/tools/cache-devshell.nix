{
  lib,
  writeShellScriptBin,
  symlinkJoin,
  coreutils,
  findutils,
  attic-client,
  cachix,
  ...
}: let
  # --- 1. 定义查找脚本 (cache-devshell) ---
  cacheDevShellScript = writeShellScriptBin "cache-devshell" ''
    export PATH="${lib.makeBinPath [coreutils findutils]}:$PATH"

    find_direnv_root() {
      local dir="$PWD"
      while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        if [ -d "$dir/.direnv" ]; then
          echo "$dir"
          return 0
        fi
        dir=$(dirname "$dir")
      done

      if [ -d "/.direnv" ]; then
        echo "/"
        return 0
      fi

      return 1
    }

    PROJECT_ROOT=$(find_direnv_root)

    if [ -z "$PROJECT_ROOT" ]; then
      echo "⚠️  [Error] Could not find parent directory with .direnv folder." >&2
      exit 1
    fi

    TARGET_PROFILE=$(find "$PROJECT_ROOT/.direnv" -maxdepth 1 -name "flake-profile-*" -type l 2>/dev/null | head -n 1)

    if [ -n "$TARGET_PROFILE" ]; then
      REAL_PATH=$(readlink -f "$TARGET_PROFILE")
      echo "🚀 [Info] Found Root: $PROJECT_ROOT" >&2
      echo "👉 [Info] Store Path: $REAL_PATH" >&2
      echo "$REAL_PATH"
    else
      echo "⚠️  [Error] No valid .direnv profile found in $PROJECT_ROOT/.direnv" >&2
      exit 1
    fi
  '';

  # --- 2. 定义推送脚本 (push-shell) ---
  pushShellScript = writeShellScriptBin "push-shell" ''
    export PATH="${lib.makeBinPath [attic-client cachix cacheDevShellScript]}:$PATH"

    set -e
    echo "🔍 Calculating devShell path..."
    STORE_PATH=$(cache-devshell)

    set +e
    echo "📦 Pushing to Attic (r2)..."
    attic push r2 "$STORE_PATH"

    echo "📦 Pushing to Cachix (kurikomoe)..."
    echo "$STORE_PATH" | cachix push kurikomoe

    echo "✅ All done!"
  '';
in
  # --- 3. 合并输出 ---
  # 使用 symlinkJoin 把两个脚本合并到一个包里
  symlinkJoin {
    name = "devshell-cache-tools";
    paths = [cacheDevShellScript pushShellScript];

    meta = {
      description = "Tools to discover and push direnv devShells to binary caches";
      homepage = "https://github.com/kurikomoe";
      mainProgram = "push-shell";
    };
  }
