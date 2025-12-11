{
  pkgs' ? null,
  pkgs-kuriko-nur' ? null,
  pre-commit-hooks' ? null,
  precommit-trufflehog ? null,
}: let
  pkgs =
    if pkgs' == null
    then import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-25.11") {}
    else pkgs';

  inherit (pkgs) lib fetchFromGitHub;
  system = pkgs.stdenv.hostPlatform.system;

  pkgs-kuriko-nur =
    if pkgs-kuriko-nur' == null
    then
      import (fetchFromGitHub {
        owner = "kurikomoe";
        repo = "nur-packages";
        rev = "main";
      }) {}
    else pkgs-kuriko-nur';

  pre-commit-hooks =
    if pre-commit-hooks' == null
    then import (builtins.fetchTarball "https://github.com/cachix/git-hooks.nix/tarball/master")
    else pre-commit-hooks';

  precommit-trufflehog' =
    if precommit-trufflehog == null
    # then pkgs-kuriko-nur'.legacyPackages.${system}.precommit-trufflehog
    then pkgs.callPackage ./pkgs/tools/precommit-trufflehog.nix {}
    else precommit-trufflehog;
  # precommit-trufflehog' = builtins.trace _precommit-trufflehog' _precommit-trufflehog';
in rec {
  pre-commit-check = pre-commit-hooks.lib.${system}.run {
    src = ./.;

    hooks = {
      alejandra.enable = true;
      trufflehog = {
        enable = true;
        entry = builtins.toString precommit-trufflehog';
        stages = ["pre-push" "pre-commit"];
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
      ]
      ++ pre-commit-check.enabledPackages;
  };
}
