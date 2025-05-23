# default.nix
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.11";
  pkgs = import nixpkgs {
    config = {};
    overlays = [];
  };
in {
  hello = pkgs.callPackage ./nutstore.nix {};
}
