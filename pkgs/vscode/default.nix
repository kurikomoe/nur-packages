{
  lib,
  pkgs,
  inputs,
  sources,
  callPackage,
  vscode,
  ...
}: let
  deps = callPackage ./plugins.nix {inherit pkgs sources inputs;};

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
