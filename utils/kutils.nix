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

  inspectAttrset = x: (
    builtins.trace
    (
      builtins.attrNames (
        lib.attrsets.filterAttrs
        (k: v: (lib.attrByPath ["meta" "hidden"] null v) != true)
        x
      )
    )
    x
  );

  # inspectPkgs = x: (
  #   builtins.trace
  #   (
  #     lib.attrsets.mapAttrsToList
  #     (k: v: toString (v.name or "${v.pname}-${v.version}"))
  #     (lib.attrsets.filterAttrs (k: v: (lib.attrByPath ["meta" "hidden"] null v) != true) x)
  #   )
  #   x
  # );

  inspectPkgs = x: (
    let
      filtered = lib.attrsets.filterAttrs (k: v: (lib.attrByPath ["meta" "hidden"] null v) != true) x;
      pkgsList =
        lib.attrsets.mapAttrsToList (
          k: v: "${k}: ${v.name or "${v.pname or "unnamed"}-${v.version or "unversioned"}"}"
        )
        filtered;
    in
      builtins.trace (lib.concatStringsSep "\n" pkgsList) x
  );

  genPkgAttrset = xs:
    lib.listToAttrs (map (x: {
        name = x.pname or x.name;
        value = x;
      })
      xs);
}
