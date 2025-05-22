{
  pkgs,
  lib,
  sources,
  ...
}: let
  res = sources.kratos;
in
  pkgs.buildGoModule rec {
    inherit (res) pname version src;

    proxyVendor = true;
    sourceRoot = "source/cmd/kratos";

    preBuild = ''
      go mod tidy
    '';

    doCheck = false;

    # NOTE(kuriko): when updating, use lib.fakeHash first to obtain new hash,
    #   otherwise nix will directly use the old cache (without rebuilding and comparing hash)
    vendorHash = "sha256-lDekJQAOrCx6gsZ2J8cRmgTjL+WcWK0iejC/CbdxO6U=";

    ldflags = ["-s -w"];

    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
