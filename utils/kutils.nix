{
  lib,
  system,
  stdenv,
  callPackage,
  ...
}: let
  getResBySystem = pname: reses: let
    system = stdenv.hostPlatform.system;
  in
    if (builtins.hasAttr system reses)
    then reses.${system}
    else throw "Source for ${pname} is not available for ${system}";
in {
  inherit getResBySystem;

  buildCallPackage = params: x: args: callPackage x (params // args // {inherit params;});

  inspectAttrset = x: (builtins.trace (builtins.attrNames x) x);

  genPkgAttrset = xs:
    lib.listToAttrs (map (x: {
        name = x.pname or x.name;
        value = x;
      })
      xs);
}
