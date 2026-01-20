# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  pkgs ? import <nixpkgs> {},
  inputs ? {
    flake-compat = builtins.fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/v1.1.0.tar.gz";
      sha256 = "19d2z6xsvpxm184m41qrpi1bplilwipgnzv9jy17fgw421785q1m";
    };
  },
  ...
}: let
  root = rec {
    base = ./.;
    res = "${base}/res";
    pkgs = "${base}/pkgs";
    utils = "${base}/utils";
  };

  lib = pkgs.lib;
  kutils = pkgs.callPackage "${root.utils}/kutils.nix" {};
  sources = pkgs.callPackages ./_sources/generated.nix {};

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
      # (kallPackage ./pkgs/lix.nix {})
      (kallPackage ./pkgs/determinate.nix {}) # determinate-nix
      (kallPackage ./pkgs/deploy-rs.nix {})
      # (kallPackage ./pkgs/doxx.nix {})
      (kallPackage ./pkgs/tools/precommit-trufflehog.nix {})
      (kallPackage ./pkgs/git-hooks.nix {})
    ])
    {
      # The `lib`, `modules`, and `overlays` names are special
      lib = import ./lib {inherit pkgs;}; # functions
      modules = import ./modules; # NixOS modules
      overlays = import ./overlays; # nixpkgs overlays

      "example-package" = kallPackage ./pkgs/example-package {};

      # "msedit" = pkgs.microsoft-edit.overrideAttrs (final: prev: {
      #   # meta.broken = true;
      # });

      # "devenv" = kallPackage ./pkgs/devenv.nix {};
      "trzsz" = kallPackage ./pkgs/trzsz-ssh.nix {};
      "python" = kallPackage ./pkgs/python/default.nix {};
      # "vscode" = kallPackage ./pkgs/vscode/default.nix {};
      # "jetbrains" = kallPackage ./pkgs/jetbrains.nix {};
    }
    fonts
  ];
  # checkNameMatch = k: v: let
  #   name =
  #     if v ? pname
  #     then v.pname
  #     else if v ? name
  #     then v.name
  #     else null;
  #   warn = name != null && name != k;
  #
  #   _v =
  #     if warn
  #     then lib.warn "包名称不匹配: 预期 '${k}' 但得到 '${name}'" v
  #     else v;
  # in _v;
in
  nur-pkgs
