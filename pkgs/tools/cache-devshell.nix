{
  lib,
  writeShellScriptBin,
  coreutils,
  findutils,
  ...
}: let
  script = writeShellScriptBin "cache-devshell" ''
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

  output = script.overrideAttrs (final: prev: {
    meta = {
      description = "Output devShell path by finding .direnv recursively";
      homepage = "https://github.com/kurikomoe";
    };
  });
in
  output
