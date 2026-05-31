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
    vendorHash = "sha256-i2dOY/incZ4JdYui8PZvN8eWdNHbHi3a38Zkqy8+lRM=";

    ldflags = ["-s -w"];
    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
