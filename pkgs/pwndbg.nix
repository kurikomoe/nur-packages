{
  lib,
  inputs,
  sources,
  stdenv,
  ...
}: let
  system = stdenv.hostPlatform.system;
  res = sources.pwndbg;
  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  # pwndbg = builtins.trace (builtins.attrNames flake.defaultNix) flake.defaultNix;
  pwndbg = flake.defaultNix.packages.${system}.default;
in
  pwndbg.overrideAttrs (final: prev: {
    meta = with lib; {
      description = "Exploit Development and Reverse Engineering with GDB Made Easy";
      mainProgram = "pwndbg";
      homepage = "https://github.com/pwndbg/pwndbg";
      license = licenses.mit;
      platforms = platforms.all;
      # not supported on aarch64-darwin see: https://inbox.sourceware.org/gdb/3185c3b8-8a91-4beb-a5d5-9db6afb93713@Spark/
      broken = stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64;
    };
  })
