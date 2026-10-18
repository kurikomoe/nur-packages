{
  lib,
  inputs,
  sources,
  stdenv,
  ...
}: let
  system = stdenv.hostPlatform.system;
  res = sources.tgt;
  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };
  tgt = flake.defaultNix.packages.${system}.default;
in
  tgt.overrideAttrs (final: prev: {
    meta =
      prev.meta
      // {
        mainProgram = "tgt";
        license = with lib.licenses; [mit asl20];
        platforms = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
      };
  })
