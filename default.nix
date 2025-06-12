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
    (kutils.genPkgAttrset [
      (kallPackage ./pkgs/kratos.nix {})
      (kallPackage ./pkgs/goctl.nix {})
      (kallPackage ./pkgs/1password-cli.nix {})
      (kallPackage ./pkgs/dotnet-script.nix {})
      (kallPackage ./pkgs/shellfirm.nix {})
      (kallPackage ./pkgs/microsoft-edge/package.nix {})
      (kallPackage ./pkgs/pwndbg.nix {})
      (kallPackage ./pkgs/lix.nix {})
      (kallPackage ./pkgs/deploy-rs.nix {})
      (kallPackage ./pkgs/tools/precommit-trufflehog.nix {})
    ])
    {
      # The `lib`, `modules`, and `overlays` names are special
      lib = import ./lib {inherit pkgs;}; # functions
      modules = import ./modules; # NixOS modules
      overlays = import ./overlays; # nixpkgs overlays

      "example-package" = kallPackage ./pkgs/example-package {};

      "microsoft-edit" = pkgs.microsoft-edit.overrideAttrs (final: prev: {
        # meta.broken = true;
      });

      "devenv" = kallPackage ./pkgs/devenv.nix {};
      "python" = kallPackage ./pkgs/python/default.nix {};
      "vscode" = kallPackage ./pkgs/vscode/default.nix {};
      "trzsz" = kallPackage ./pkgs/trzsz-ssh.nix {};
    }
    fonts
  ];
in
  nur-pkgs
# builtins.trace
# (let
#   isRecursiveDerivation = x:
#     builtins.isAttrs x
#       && x ? recurseForDerivations
#       && x.recurseForDerivations;
#   deepInspect = x:
#     x.pname
#     or x.name
#     or builtins.map deepInspect (
#       builtins.filter
#         isRecursiveDerivation
#         (builtins.map (x: deepInspect ) (builtins.attrValues x))
#     );
#   el = deepInspect nur-pkgs;
# in
#   builtins.deepSeq el el)
# nur-pkgs

