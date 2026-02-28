{
  pkgs,
  lib,
  sources,
  fetchFromGitHub,
  rustPlatform,
  writeTextFile,
  ...
}: let
  res = sources.shellfirm;

  shellfirmFishPlugin = writeTextFile {
    name = "shellfirm.plugin.fish";
    text = ''
      # shellfirm hook for fish — intercepts Enter via key binding
      function _shellfirm_check
          set -l cmd (commandline)
          if test -z "$cmd"; or string match -q '*shellfirm pre-command*' -- $cmd
              commandline -f execute
              return
          end
          stty sane
          shellfirm pre-command -c "$cmd"
          if test $status -eq 0
              commandline -f execute
          else
              commandline -f repaint
          end
      end
      bind \r _shellfirm_check
      # Also bind in vi insert mode if active
      bind -M insert \r _shellfirm_check 2>/dev/null

      # My custom check
      # function check_command --on-event fish_preexec
      #     stty sane
      #     set -l cmd (commandline)
      #     shellfirm pre-command --command "$argv"
      # end
    '';
    # My custom check
    # function check_command --on-event fish_preexec
    #     stty sane
    #     set -l cmd (commandline)
    #     shellfirm pre-command --command "$argv"
    # end
  };
in
  rustPlatform.buildRustPackage rec {
    inherit (res) pname version src;

    # useFetchCargoVendor = true; # default true in 25.05
    nativeBuildInputs = with pkgs; [
      pkg-config
    ];

    buildInputs = with pkgs; [
      openssl
    ];

    OPENSSL_DIR = "${pkgs.openssl.dev}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

    cargoLock.lockFile = "${res.src}/Cargo.lock";

    postInstall = ''
      # Install the fish plugin
      # mkdir -p $out/share/fish/vendor_functions.d
      # cp -r ${shellfirmFishPlugin} $out/share/fish/vendor_functions.d/${shellfirmFishPlugin.name}

      mkdir -p $out/share/fish/vendor_conf.d
      cp -r ${shellfirmFishPlugin} $out/share/fish/vendor_conf.d/shellfirm.fish

      # Install the bash plugin
      # mkdir -p $out/share/fish/vendor_functions.d
      # cp -r ./shell-plugins/shellfirm.plugin.fish $out/share/fish/vendor_functions.d/

      # Install the zsh plugin
      # mkdir -p $out/share/zsh/site-functions
      # cp -r ./shell-plugins/shellfirm.plugin.zsh $out/share/zsh/site-functions/
    '';

    meta = {
      description = "Intercept any risky patterns (default or defined by you) and prompt you a small challenge for double verification";
      homepage = "https://github.com/kaplanelad/shellfirm";
      license = lib.licenses.asl20;
      maintainers = [];
    };
  }
