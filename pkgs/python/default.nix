{
  lib,
  sources,
  inputs,
  system,
  ...
}: let
  res = sources.python;

  nixpkgs-python = import inputs.flake-compat {
    inherit (res) src;
    inherit system;
  };

  pkgs = nixpkgs-python.defaultNix.packages.${system};
  # _pkgs = builtins.trace (builtins.attrNames _pkgs) _pkgs;
  versionList = [
    "2.7"
    "3.6"
    "3.7"
    "3.8"
    "3.9"
    "3.10"
    "3.11"
    "3.12"
  ];

  pythons = builtins.listToAttrs (
    builtins.map (x: rec {
      name = builtins.replaceStrings ["."] [""] "python${x}";
      value = pkgs.${x}.overrideAttrs (final: prev: {pname = name;});
    })
    versionList
  );
  # pythons = builtins.trace (_pythons) _pythons;
in
  {recurseForDerivations = true;} // pythons
