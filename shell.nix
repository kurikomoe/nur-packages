{
  pkgs' ? null,
  pkgs-kuriko-nur' ? null,
  pre-commit-hooks' ? null,
  precommit-trufflehog ? null,
  ...
}: let
  pkgs =
    if pkgs' == null
    then import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-25.05") {}
    else pkgs';

  inherit (pkgs) lib fetchFromGitHub system;

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
    then pkgs-kuriko-nur'.legacyPackages.${system}.precommit-trufflehog
    else precommit-trufflehog;
in rec {
  pre-commit-check = pre-commit-hooks.run {
    src = ./.;

    hooks = {
      alejandra.enable = true;
      trufflehog = {
        enable = true;
        entry = builtins.toString precommit-trufflehog;
        stages = ["pre-push" "pre-commit"];
      };
    };
  };

  devShells.default = pkgs.mkShell {
    inherit (pre-commit-check) shellHook;

    packages = with pkgs;
      [
        nvfetcher
        nix-update
      ]
      ++ pre-commit-check.enabledPackages;
  };
}
