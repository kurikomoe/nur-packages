{
  lib,
  inputs,
  sources,
  system,
  stdenv,
  ...
}: let
  res = sources.devenv;
  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  packages = flake.defaultNix.packages.${system};
  # packages = builtins.trace (builtins.attrNames _packages) _packages;
in {
  inherit (packages) default devenv-tasks;
  recurseForDerivations = true;
}
