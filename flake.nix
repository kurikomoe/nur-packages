{
  description = "My personal NUR repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "i686-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    legacyPackages = forAllSystems (system:
      import ./default.nix {
        pkgs = import nixpkgs {inherit system;};
      });

    packages = forAllSystems (system: nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system});

    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });

    checks = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
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
    });
  };
}
