{
  lib,
  inputs,
  sources,
  stdenv,
  ...
}: let
  system = stdenv.hostPlatform.system;
  lix-res = sources.lix;

  flake = import inputs.flake-compat {
    inherit system;
    src = lix-res.src;
  };

  lix = flake.defaultNix.packages.${system}.default;
in
  lix.overrideAttrs (final: prev: {
    meta.broken = true;
  })
