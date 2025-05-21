{
  description = "My personal NUR repository";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";

    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    pwndbg.url = "github:pwndbg/pwndbg/2025.04.18";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
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
        buildOutputs = convert2attrset ci.buildOutputs;
        cacheOutputs = convert2attrset ci.cacheOutputs;
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        ci = cacheOutputs;

        legacyPackages = buildOutputs;

        packages = nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) legacyPackages;

        devShells = {
          default = nixpkgs.legacyPackages.${system}.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        };

        checks.pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
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
