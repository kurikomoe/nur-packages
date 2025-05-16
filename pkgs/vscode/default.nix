{
  pkgs,
  callPackage,
  vscode,
  ...
}: let
  deps = callPackage ./plugins.nix {inherit pkgs;};

  vscodeWithExtensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = deps.extensions;
  };
in
  vscodeWithExtensions
