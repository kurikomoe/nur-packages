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
  lib = pkgs.lib;
  kutils = pkgs.callPackage ./utils/kutils.nix {};
  sources = pkgs.callPackages ./_sources/generated.nix {};

  extraArgs = {inherit inputs sources kutils;};
  kcallPackage = kutils.buildCallPackage extraArgs;

  font-set = kcallPackage ./pkgs/fonts {};
  python-set = kcallPackage ./pkgs/python/default.nix {};
  trzsz-set = kcallPackage ./pkgs/trzsz-ssh.nix {};
  hermes-agent-set = kcallPackage ./pkgs/hermes-agent.nix {};
in
  {}
  // font-set
  // python-set
  // trzsz-set
  // hermes-agent-set
  // {
    "1password-cli" = kcallPackage ./pkgs/1password-cli.nix {};
    kratos = kcallPackage ./pkgs/kratos.nix {};
    goctl = kcallPackage ./pkgs/goctl.nix {};
    opencode = kcallPackage ./pkgs/opencode.nix {};
    opencode-bin = kcallPackage ./pkgs/opencode-bin.nix {};
    codex = kcallPackage ./pkgs/codex.nix {};
    "cc-switch-cli" = kcallPackage ./pkgs/cc-switch-cli.nix {};
    dotnet-script = kcallPackage ./pkgs/dotnet-script.nix {};
    shellfirm = kcallPackage ./pkgs/shellfirm.nix {};
    microsoft-edge = kcallPackage ./pkgs/microsoft-edge/package.nix {};
    pwndbg = kcallPackage ./pkgs/pwndbg.nix {};
    determinate = kcallPackage ./pkgs/determinate.nix {};
    deploy-rs = kcallPackage ./pkgs/deploy-rs.nix {};
    git-hooks = kcallPackage ./pkgs/git-hooks.nix {};

    # 工具类
    precommit-trufflehog = kcallPackage ./pkgs/tools/precommit-trufflehog.nix {};
    devshell-cache-tools = kcallPackage ./pkgs/tools/cache-devshell.nix {};

    # 测试用对象
    example-package = kcallPackage ./pkgs/example-package {};

    # 集合
    fontSet = font-set;
    pythonSet = python-set;
    trzszSet = trzsz-set;
    hermesAgentSet = hermes-agent-set;

    # 特殊模块保留
    lib = import ./lib {inherit pkgs;};
    modules = import ./modules;
    overlays = import ./overlays;
  }
