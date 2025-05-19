{
  pkgs,
  lib,
  callPackage,
  vscode,
  ...
}: let
  deps = callPackage ./plugins.nix {inherit pkgs;};

  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = deps.extensions;
  };
in
  {
    inherit vscodeWithExtensions;
    recurseForDerivations = true;
  }
  // lib.listToAttrs (lib.map (x: {
      name = x.name;
      value = x;
    })
    deps.extensions)
