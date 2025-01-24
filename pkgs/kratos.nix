{ pkgs, lib, ... }:
let
  repoHash = "sha256-RrB0xXLr/AstAw+t+0e/eV2FBwU7WwgOH/rpYGPIjz8=";
  vendorHash = "sha256-lDekJQAOrCx6gsZ2J8cRmgTjL+WcWK0iejC/CbdxO6U=";

in pkgs.buildGoModule rec {
  pname = "kratos";
  version = "2.8.3";

  src = pkgs.fetchFromGitHub {
    owner = "go-kratos";
    repo = "kratos";
    rev = "v${version}";
    sha256 = repoHash;
  };

  proxyVendor = true;
  sourceRoot = "source/cmd/kratos";

  preBuild = ''
    go mod tidy
  '';

  doCheck = false;

  # NOTE(kuriko): when updating, use lib.fakeSha first to obtain new hash,
  #   otherwise nix will directly use the old cache (without rebuilding and comparing hash)
  inherit vendorHash;

  ldflags = [ "-s -w" ];
}
