{
  lib,
  inputs,
  sources,
  system,
  ...
}: let
  determinate-res = sources.determinate;

  flake = import inputs.flake-compat {
    inherit system;
    src = determinate-res.src;
  };

  determinate = flake.defaultNix.packages.${system}.default;
in
  determinate
