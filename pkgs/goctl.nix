{
  lib,
  system,
  sources,
  buildGoModule,
  fetchFromGitHub,
  ...
}: let
  res = sources.goctl;
  # nixpkgs_go_121 = fetchFromGitHub {
  #   owner = "NixOS";
  #   repo = "nixpkgs";
  #   rev = "a71323f68d4377d12c04a5410e214495ec598d4c";
  #   hash = "sha256-pl8PLUQLigZgFZrafIXs2djne5kboimK6MYsZN8Ywtg=";
  # };
  #
  # pkgs_go_121 = import nixpkgs_go_121 { inherit system; };
  #
  # buildGoModule = pkgs_go_121.buildGoModule;
in
  buildGoModule rec {
    inherit (res) pname version src;

    proxyVendor = true;
    sourceRoot = "source/tools/goctl";

    preBuild = ''
      go version
      go mod tidy
      go mod vendor
    '';

    doCheck = false;

    # NOTE(kuriko): when updating, use lib.fakeSha first to obtain new hash,
    #   otherwise nix will directly use the old cache (without rebuilding and comparing hash)
    vendorHash = "sha256-onq94kVxAb7zItRR1gfTCtcmD1Jz9V1POutGJm0l3V8=";

    ldflags = ["-s -w"];

    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
