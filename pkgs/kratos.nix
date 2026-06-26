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
    vendorHash = "sha256-UYkV3W8tyF3dr+ebH3jN3UhEckjicE3G8jK2EsOcsPc=";

    ldflags = ["-s -w"];

    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
