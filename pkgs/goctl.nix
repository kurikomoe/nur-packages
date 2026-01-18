{
  lib,
  stdenv,
  sources,
  buildGoModule,
  fetchFromGitHub,
  ...
}: let
  system = stdenv.hostPlatform.system;
  res = sources.goctl;
in
  buildGoModule rec {
    inherit (res) pname version src;
    sourceRoot = "source/tools/goctl";

    doCheck = false;
    vendorHash = "sha256-WS9fC4pDCNsc2mQPiMk/eHYqG+tF+/J/6RaMYM0/ql0=";

    ldflags = ["-s -w"];
    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
