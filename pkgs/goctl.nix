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
    vendorHash = "sha256-MD9w/Q1dRBn/kUMm7dLnLawTr31t71VSVjwnssS01UE=";

    ldflags = ["-s -w"];
    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
