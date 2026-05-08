{
  lib,
  sources,
  inputs,
  stdenv,
  ...
}: let
  inherit (stdenv.hostPlatform) system;
  res = sources.hermes-agent;

  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  hermes = flake.defaultNix.packages.${system}.default;
  tui = flake.defaultNix.packages.${system}.tui or null;
  web = flake.defaultNix.packages.${system}.web or null;

  meta = with lib; {
    description = "AI agent with advanced tool-calling capabilities by Nous Research";
    homepage = "https://github.com/NousResearch/hermes-agent";
    license = licenses.mit;
    platforms = platforms.unix;
  };
in
  {
    hermes-agent = hermes.overrideAttrs (final: prev: {meta = (prev.meta or {}) // meta;});
  }
  // (lib.optionalAttrs (tui != null) {
    hermes-tui = tui.overrideAttrs (final: prev: {meta = (prev.meta or {}) // meta;});
  })
  // (lib.optionalAttrs (web != null) {
    hermes-web = web.overrideAttrs (final: prev: {meta = (prev.meta or {}) // meta;});
  })
