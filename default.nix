# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  pkgs ? import <nixpkgs> {},
  inputs,
  sources,
  root,
  ...
}: let
  lib = pkgs.lib;
  kutils = pkgs.callPackage "${root.utils}/kutils.nix" {};

  params = {inherit inputs sources kutils root;};
  kallPackage = kutils.buildCallPackage params;

  fonts = kallPackage ./pkgs/fonts {};

  nur-pkgs = lib.attrsets.mergeAttrsList [
    {
      # The `lib`, `modules`, and `overlays` names are special
      lib = import ./lib {inherit pkgs;}; # functions
      modules = import ./modules; # NixOS modules
      overlays = import ./overlays; # nixpkgs overlays

      # "example-package" = pkgs.kallPackage ./pkgs/example-package {};

      "kratos" = kallPackage ./pkgs/kratos.nix {};
      "goctl" = kallPackage ./pkgs/goctl.nix {};
      "1password-cli" = kallPackage ./pkgs/1password-cli.nix {};
      "dotnet-script" = kallPackage ./pkgs/dotnet-script.nix {};
      "kfonts" = kallPackage ./pkgs/kfonts.nix {};
      "shellfirm" = kallPackage ./pkgs/shellfirm.nix {};
      "vscode" = kallPackage ./pkgs/vscode/default.nix {};

      "microsoft-edge" = kallPackage ./pkgs/microsoft-edge/package.nix {};

      "precommit-trufflehog" = kallPackage ./pkgs/tools/precommit-trufflehog.nix {};

      "microsoft-edit" = pkgs.microsoft-edit.overrideAttrs (final: prev: {
        # meta.broken = true;
      });

      "pwndbg" = kallPackage ./pkgs/pwndbg.nix {};

      "lix" = kallPackage ./pkgs/lix.nix {};

      "devenv" = kallPackage ./pkgs/devenv.nix {};

      "python" = kallPackage ./pkgs/python/default.nix {};
    }
    fonts
  ];
in
  kutils.inspectAttrset nur-pkgs
