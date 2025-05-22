{
  pkgs,
  stdenv,
  ...
}:
with pkgs.lib; {
  getResBySystem = pname: reses: let
    system = stdenv.hostPlatform.system;
  in
    if (builtins.hasAttr system reses)
    then reses.${system}
    else throw "Source for ${pname} is not available for ${system}";
}
