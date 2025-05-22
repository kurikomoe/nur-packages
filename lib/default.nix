{pkgs}:
with pkgs.lib; {
  getResBySystem = pname: reses:
    if (builtins.elem system platforms)
    then reses.${system}
    else throw "Source for ${pname} is not available for ${system}";
}
