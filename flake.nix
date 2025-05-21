{
  description = "My personal NUR repository";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";

    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    pwndbg.url = "github:pwndbg/pwndbg/2025.04.18";

    kuriko-nixos.url = "github:kurikomoe/NixOS-config";
    kuriko-nixos.flake = false;
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      flake = {};
      imports = [];
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
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        # legacyPackages = import ./default.nix {inherit pkgs;};
        legacyPackages = let
          output1 = (import ./ci.nix {inherit pkgs inputs;}).cachePkgs;
          output2 =
            builtins.map (x: {
              name = x.pname or x.name;
              value = x;
            })
            output1;
          output = builtins.listToAttrs output2;
        in
          # output;
          builtins.trace (builtins.attrNames output) output;

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
              entry = let
                script = pkgs.writeShellScript "precommit-trufflehog" ''
                  set -e
                  ${pkgs.trufflehog}/bin/trufflehog git "file://$(git rev-parse --show-toplevel)" --only-verified --fail
                '';
              in
                builtins.toString script;
            };
          };
        };
      };
    };
}
