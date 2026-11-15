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
    vendorHash = "sha256-dLKcsCcODtAjMGpaGyogHk8z5e0ppJ3PoRF4NDs+Ye4=";

    ldflags = ["-s -w"];
    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
