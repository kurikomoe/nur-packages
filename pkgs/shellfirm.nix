{
  pkgs,
  lib,
  fetchFromGitHub,
  rustPlatform,
  writeTextFile,
  ...
}: let
  repoHash = "sha256-Bka3U7DHUp+KyMw0KFQtJxrHbZf4RJxmhJjgyAmVHa8=";

  shellfirmFishPlugin = writeTextFile {
    name = "shellfirm.plugin.fish";
    text = ''
      function check_command --on-event fish_preexec
          stty sane
          set -l cmd (commandline)
          shellfirm pre-command --command "$argv"
      end
    '';
  };
in
  rustPlatform.buildRustPackage rec {
    pname = "shellfirm";
    # version = "0.2.11";
    version = "unstable";

    src = fetchFromGitHub {
      owner = "kaplanelad";
      repo = "shellfirm";
      # tag = "v${version}";
      rev = "main";
      hash = repoHash;
    };

    cargoLock = {
      lockFile = "${src}/Cargo.lock";
    };
    # useFetchCargoVendor = true;
    # inherit cargoHash;

    postInstall = ''
      # Install the fish plugin
      mkdir -p $out/share/fish/vendor_functions.d
      cp -r ${shellfirmFishPlugin} $out/share/fish/vendor_functions.d/${shellfirmFishPlugin.name}

      # Install the bash plugin
      # mkdir -p $out/share/fish/vendor_functions.d
      # cp -r ./shell-plugins/shellfirm.plugin.fish $out/share/fish/vendor_functions.d/

      # Install the zsh plugin
      mkdir -p $out/share/zsh/site-functions
      cp -r ./shell-plugins/shellfirm.plugin.zsh $out/share/zsh/site-functions/
    '';

    meta = {
      description = "Intercept any risky patterns (default or defined by you) and prompt you a small challenge for double verification";
      homepage = https://github.com/kaplanelad/shellfirm;
      license = lib.licenses.asl20;
      maintainers = [];
    };
  }
