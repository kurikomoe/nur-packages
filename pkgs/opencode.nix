{
  lib,
  sources,
  inputs,
  stdenv,
  ...
}: let
  inherit (stdenv.hostPlatform) system;

  res = sources.opencode;

  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  opencode = flake.defaultNix.packages.${system}.default;
in
  opencode.overrideAttrs (final: prev: {
    meta = with lib; {
      description = "AI-powered coding agent for the terminal";
      homepage = "https://opencode.ai";
      downloadPage = "https://github.com/anomalyco/opencode/releases";
      broken = true;
      license = licenses.mit;
    };
  })
