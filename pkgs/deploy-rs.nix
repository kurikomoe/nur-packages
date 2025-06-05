{
  lib,
  sources,
  inputs,
  kutils,
  system,
  ...
}: let
  res = sources.deploy-rs;

  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  deploy-rs = flake.defaultNix.packages.${system}.default;
in
  deploy-rs
