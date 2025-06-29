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

  # vscode-extensions =
  #   {recurseForDerivations = true;}
  #   // (lib.listToAttrs (lib.map (x: {
  #       name = x.name;
  #       value = x.overrideAttrs (final: prev: {
  #         meta = (prev.meta or {}) // {hidden = true;};
  #       });
  #     })
  #     deps.extensions));
}
