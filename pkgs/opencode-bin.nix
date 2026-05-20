{
  lib,
  sources,
  kutils,
  stdenvNoCC,
  runtimeShell,
  pkgsMusl,
  ...
}: let
  pname = "opencode-bin";

  ress = rec {
    x86_64-linux = sources.opencode-bin;
  };

  res = kutils.getResBySystem pname ress;

  platforms = builtins.attrNames ress;
  mainProgram = "opencode";
  libraryPath = lib.makeLibraryPath [
    pkgsMusl.stdenv.cc.cc.lib
    pkgsMusl.stdenv.cc.cc.libgcc
    pkgsMusl.musl
  ];
in
  stdenvNoCC.mkDerivation rec {
    inherit pname;
    inherit (res) version src;

    sourceRoot = ".";

    dontStrip = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      install -D ${mainProgram} $out/libexec/${mainProgram}
      mkdir -p $out/bin
      cat > $out/bin/${mainProgram} <<EOF
      #!${runtimeShell}
      exec ${pkgsMusl.musl}/lib/ld-musl-x86_64.so.1 --library-path ${libraryPath} $out/libexec/${mainProgram} "\$@"
      EOF
      chmod +x $out/bin/${mainProgram}
      runHook postInstall
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      checkRoot=$TMPDIR/install-check
      mkdir -p $checkRoot
      export HOME=$checkRoot/home
      export TMPDIR=$checkRoot/tmp
      mkdir -p $HOME $TMPDIR
      cd $checkRoot
      $out/bin/${mainProgram} --version
    '';

    meta = with lib; {
      description = "AI-powered coding agent for the terminal";
      homepage = "https://opencode.ai";
      downloadPage = "https://github.com/anomalyco/opencode/releases";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      license = licenses.mit;
      inherit mainProgram platforms;
    };
  }
