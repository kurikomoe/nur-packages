{
  pkgs,
  lib,
  sources,
  ...
}: let
  res = sources.goctl;
in
  pkgs.buildGoModule rec {
    inherit (res) pname version src;

    proxyVendor = true;
    sourceRoot = "source/tools/goctl";

    preBuild = ''
      go mod tidy
    '';

    doCheck = false;

    # NOTE(kuriko): when updating, use lib.fakeSha first to obtain new hash,
    #   otherwise nix will directly use the old cache (without rebuilding and comparing hash)
    vendorHash = "sha256-onq94kVxAb7zItRR1gfTCtcmD1Jz9V1POutGJm0l3V8=";

    ldflags = ["-s -w"];

    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
