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
  ...
}: let
  kutils = pkgs.callPackages ./helpers/kutils.nix {};
  callPackage = x: args: pkgs.callPackage x ({inherit inputs sources kutils;} // args);
in rec {
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib {inherit pkgs;}; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  # "example-package" = pkgs.callPackage ./pkgs/example-package {};

  "kratos" = callPackage ./pkgs/kratos.nix {};
  "goctl" = callPackage ./pkgs/goctl.nix {};

  "1password-cli" = callPackage ./pkgs/1password-cli.nix {};

  # "devcontainer" = callPackage ./pkgs/devcontainer.nix {};

  "dotnet-script" = callPackage ./pkgs/dotnet-script.nix {};

  "kfonts" = callPackage ./pkgs/kfonts.nix {};

  "shellfirm" = callPackage ./pkgs/shellfirm.nix {};

  "vscode" = callPackage ./pkgs/vscode/default.nix {};

  "pwndbg" = pkgs.pwndbg;

  "precommit-trufflehog" = callPackage ./pkgs/tools/precommit-trufflehog.nix {};
}
