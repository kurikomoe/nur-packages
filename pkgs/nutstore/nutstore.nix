{
  pkgs,
  stdenv,
  fetchzip,
  ...
}: let
in
  stdenv.mkDerivation {
    pname = "nutstore";
    version = "6.4.1";

    src = fetchurl {
      url = "https://www.jianguoyun.com/static/exe/installer/nutstore_linux_dist_x64.tar.gz";
      hash = "";
    };

    nativeBuildInputs = with pkgs; [
      python311Packages.pygobject3
      gtk2
      nautilus
      jre8
    ];

    buildPhase = ''
      dpkg -x nautilus_nutstore_amd64.deb

      cd usr

      mkdir -p $out
      cp -r lib share $out/
    '';
  }
