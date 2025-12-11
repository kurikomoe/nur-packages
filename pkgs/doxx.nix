{
  lib,
  sources,
  inputs,
  kutils,
  stdenv,
  pkgs,
  libxcb ? pkgs.xorg.libxcb,
  rustPlatform,
  ...
}: let
  system = stdenv.hostPlatform.system;
  res = sources.doxx;
in
  rustPlatform.buildRustPackage rec {
    inherit (res) pname version src;

    cargoLock.lockFile = "${res.src}/Cargo.lock";

    buildInputs = [
      libxcb
    ];

    doCheck = false;

    meta = {
      description = "Expose the contents of .docx files without leaving your terminal. Fast, safe, and smart — no Office required!";
      homepage = "https://github.com/bgreenwell/doxx";
      license = lib.licenses.mit;
      maintainers = [];
    };
  }
