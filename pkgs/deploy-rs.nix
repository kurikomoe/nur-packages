{
  lib,
  sources,
  inputs,
  kutils,
  stdenv,
  ...
}: let
  system = stdenv.hostPlatform.system;
  res = sources.deploy-rs;

  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  deploy-rs = flake.defaultNix.packages.${system}.default;
in
  deploy-rs
