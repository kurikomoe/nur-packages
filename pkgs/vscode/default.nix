{
  inputs,
  pkgs,
  lib,
  callPackage,
  vscode,
  ...
}: let
  # repos = rec {
  #   inherit pkgs;
  #   pkgs-unstable = pkgs;
  #   pkgs-kuriko-nur = pkgs;
  # };
  # deps = callPackage "${inputs.kuriko-nixos}/home-manager/pkgs/devs/ide/vscode/plugins.nix" {inherit pkgs repos;};
  deps = callPackage ./plugins.nix {inherit pkgs;};

  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = deps.extensions;
  };
in {
  recurseForDerivations = true;

  inherit vscodeWithExtensions;

  vscode-extensions =
    {recurseForDerivations = true;}
    // (lib.listToAttrs (lib.map (x: {
        name = x.name;
        value = x;
      })
      deps.extensions));
}
