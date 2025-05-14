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

    src = fetchzip {
      url = https://www.jianguoyun.com/static/exe/installer/nutstore_linux_src_installer.tar.gz;
      hash = "sha256-G74Q51jCkZvNXX26aaSEzbQm3L0cGkiCfrb14JaMF/4=";
    };

    nativeBuildInputs = with pkgs; [
      bash

      autoconf
      automake
      libtool

      pkg-config

      python311Packages.pygobject3

      gtk2
      nautilus
      jre8
    ];

    buildPhase = ''
      ls
      bash update-toolchain.sh
      ./configure
      make

    '';
  }
