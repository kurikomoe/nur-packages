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

  _packages = flake.defaultNix.packages.${system};
  packages = builtins.trace (builtins.attrNames _packages) _packages;
in
  {
    recurseForDerivations = true;
  }
  // packages
