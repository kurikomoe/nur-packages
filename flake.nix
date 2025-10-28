{
  description = "Kuriko's personal NUR repository";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat.url = "github:nix-community/flake-compat";
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
        root = rec {
          base = ./.;
          res = "${base}/res";
          pkgs = "${base}/pkgs";
          utils = "${base}/utils";
        };

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            # inputs.nix-vscode-extensions.overlays.default
            (final: prev: {
              # pwndbg = inputs.pwndbg.packages.${system}.default;
              # microsoft-edit = inputs.nixpkgs-microsoft-edit.legacyPackages.${system}.msedit;
            })
          ];
        };

        kutils = pkgs.callPackage "${root.utils}/kutils.nix" {};
      in let
        convert2attrset = x:
          builtins.listToAttrs (builtins.map (x: {
              name = x.pname or x.name;
              value = x;
            })
            x);

        ci = import ./ci.nix {inherit pkgs inputs root;};
        buildOutputs = convert2attrset ci.buildPkgs;
        # buildOutputs = kutils.inspectPkgs _buildOutputs;
        # buildOutputs = builtins.trace
        #   (builtins.map
        #     (x: let el = x.pname or x.name or "<no-name>"; in builtins.deepSeq el el)
        #     (builtins.attrValues _buildOutputs))
        #   _buildOutputs;
        cacheOutputs = convert2attrset ci.cacheOutputs;

        shellNix = import ./shell.nix {
          pkgs' = pkgs;
          inherit (buildOutputs) precommit-trufflehog;
        };
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        ci = cacheOutputs;

        legacyPackages = buildOutputs;

        checks = ci;

        packages = nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) legacyPackages;

        inherit (shellNix) devShells;
      };
    };
}
