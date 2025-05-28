{
  description = "My personal NUR repository";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";

    nixpkgs-ms-edit.url = "github:NixOS/nixpkgs/pull/409075/head";

    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    pwndbg.url = "github:pwndbg/pwndbg/2025.04.18";
  };

  nixConfig = {
    substituters = [
      https://mirrors.ustc.edu.cn/nix-channels/store
      https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store
      https://nix-community.cachix.org
      https://kurikomoe.cachix.org
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "kurikomoe.cachix.org-1:NewppX3NeGxT8OwdwABq+Av7gjOum55dTAG9oG7YeEI="
    ];
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
        ({
          flake-parts-lib,
          lib,
          ...
        }: let
          inherit (flake-parts-lib) mkTransposedPerSystemModule;
          inherit (lib) mkOption types;
        in
          mkTransposedPerSystemModule {
            name = "ci";
            option = mkOption {
              type = types.lazyAttrsOf types.package;
              default = {};
              description = ''
                ci only packages
                nix run -f '<nixpkgs>' nix-fast-build -- -f .#ci --skip-cached
              '';
            };
            file = ./ci.nix;
          })
      ];
      systems = [
        "x86_64-linux"
        # "i686-linux"
        # "aarch64-linux"
        # "armv6l-linux"
        # "armv7l-linux"
        # "x86_64-darwin"
      ];

      perSystem = {
        config,
        system,
        ...
      }: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.nix-vscode-extensions.overlays.default
            (final: prev: {
              pwndbg = inputs.pwndbg.packages.${system}.default;
              ms-edit = inputs.nixpkgs-ms-edit.legacyPackages.${system}.ms-edit;
            })
          ];
        };
      in let
        convert2attrset = x:
          builtins.listToAttrs (builtins.map (x: {
              name = x.pname or x.name;
              value = x;
            })
            x);

        ci = import ./ci.nix {inherit pkgs inputs;};
        buildOutputs = convert2attrset ci.buildPkgs;
        # buildOutputs = builtins.trace (builtins.attrNames _buildOutputs) _buildOutputs;
        cacheOutputs = convert2attrset ci.cacheOutputs;
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        ci = cacheOutputs;

        legacyPackages = buildOutputs;

        packages = nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) legacyPackages;

        devenv.shells.default = {
          packages = with pkgs; [
            nvfetcher
          ];

          git-hooks.hooks = {
            alejandra.enable = true;
            trufflehog = {
              enable = true;
              entry = builtins.toString packages.precommit-trufflehog;
              stages = ["pre-push" "pre-commit"];
            };
          };
        };
      };
    };
}
