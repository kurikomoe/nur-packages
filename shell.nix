inputs @ {
  pkgs ? null,
  pre-commit-hooks ? null,
  pkgs-kuriko-nur ? null,
}: let
  pre-commit-hooks = inputs.pre-commit-hooks or
    (import (builtins.fetchTarball "https://github.com/cachix/git-hooks.nix/tarball/master") {});

  pkgs = inputs.pkgs or
    (import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-25.11") {});

  inherit (pkgs) lib fetchFromGitHub;
  system = pkgs.stdenv.hostPlatform.system;

  pkgs-kuriko-nur =
    inputs.pkgs-kuriko-nur or (import (fetchFromGitHub {
      owner = "kurikomoe";
      repo = "nur-packages";
      rev = "main";
    }) {});

  inherit (pkgs-kuriko-nur) precommit-trufflehog devshell-cache-tools;
in rec {
  pre-commit-check = pre-commit-hooks.lib.${system}.run {
    src = ./.;

    hooks = {
      alejandra.enable = true;
      trufflehog = {
        enable = true;
        entry = lib.getExe precommit-trufflehog;
        stages = ["pre-push" "pre-commit"];
      };
      devshell = {
        enable = true;
        entry = lib.getExe devshell-cache-tools;
        stages = ["pre-push"];
        verbose = true;
        pass_filenames = false;
        always_run = true;
      };
    };
  };

  devShells.default = pkgs.mkShell {
    shellHook = ''
      ${pre-commit-check.shellHook}
      hello
    '';

    packages = with pkgs;
      [
        hello
        nvfetcher
        nix-update
        devshell-cache-tools
        nix-init
        nurl
      ]
      ++ pre-commit-check.enabledPackages;
  };
}
