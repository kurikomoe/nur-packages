{
  pkgs,
  lib,
  ...
}: let
in
  pkgs.buildGoModule rec {
    pname = "goctl";
    version = "1.8.3";

    src = pkgs.fetchFromGitHub {
      owner = "zeromicro";
      repo = "go-zero";
      rev = "v${version}";
      sha256 = "sha256-eh1gxVQnknu82F/8ZC9SmPh+C1pU904WJwRLMjKBrIw=";
    };

    proxyVendor = true;
    sourceRoot = "source/tools/goctl";

    preBuild = ''
      go mod tidy
    '';

    doCheck = false;

    # NOTE(kuriko): when updating, use lib.fakeSha first to obtain new hash,
    #   otherwise nix will directly use the old cache (without rebuilding and comparing hash)
    vendorHash = "sha256-ntirLpyf90N3SREgKvzkPw7kcr0FwskPKvlfGaxLS4Y=";

    ldflags = ["-s -w"];

    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
