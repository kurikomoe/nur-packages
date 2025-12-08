{
  lib,
  inputs,
  sources,
  system,
  ...
}: let
  git-hooks-res = sources.git-hooks-nix;

  flake = import inputs.flake-compat {
    inherit system;
    src = git-hooks-res.src;
  };

  git-hooks = flake.defaultNix.packages.${system}.default;
  # git-hooks = builtins.trace _git-hooks _git-hooks;
in
  git-hooks.overrideAttrs (final: prev: rec {
    pname = "git-hooks";
    meta.broken = false;
    meta.mainProgram = "pre-commit";
  })
