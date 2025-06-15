{
  lib,
  inputs,
  sources,
  system,
  stdenv,
  jetbrains,
  ...
}: let
  ides = with jetbrains; [
    webstorm
    rust-rover
    pycharm-professional
    rider
    idea-ultimate
    goland
    clion
  ];
in
  {recurseForDerivations = true;}
  // (
    builtins.listToAttrs (
      builtins.map (
        x:
          lib.attrsets.nameValuePair
          (x.pname or x.name)
          (x.overrideAttrs {preferLocalBuild = false;})
      )
      ides
    )
  )
