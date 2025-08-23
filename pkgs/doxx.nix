{
  lib,
  sources,
  inputs,
  kutils,
  system,
  pkgs,
  libxcb ? pkgs.xorg.libxcb,
  rustPlatform,
  ...
}: let
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
