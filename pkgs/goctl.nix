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
    sourceRoot = "source/tools/goctl";

    doCheck = false;
    vendorHash = "sha256-wAQF2twQSKD8rxBchU/L4o8Z5noGK/ITAelUAHMj5gg=";

    ldflags = ["-s -w"];
    # latest vesion: https://github.com/go-kratos/kratos/tags
  }
