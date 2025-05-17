{
  description = "My personal NUR repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";

    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    pwndbg.url = "github:pwndbg/pwndbg/2025.04.18";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      # "i686-linux"
      # "aarch64-linux"
      # "armv6l-linux"
      # "armv7l-linux"
      # "x86_64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    legacyPackages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.nix-vscode-extensions.overlays.default
          ];
        };
      in (import ./default.nix {inherit pkgs inputs;})
    );

    ci = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.nix-vscode-extensions.overlays.default
          ];
        };
        output1 = (import ./ci.nix {inherit pkgs inputs;}).cachePkgs;
        output2 =
          builtins.map (x: {
            name = x.name;
            value = x;
          })
          output1;
        output = builtins.listToAttrs output2;
      in
        output
    );

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
