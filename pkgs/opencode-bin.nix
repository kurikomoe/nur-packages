{
  lib,
  sources,
  kutils,
  stdenv,
  autoPatchelfHook,
  ...
}: let
  pname = "opencode-bin";

  ress = rec {
    x86_64-linux = sources.opencode-bin;
  };

  res = kutils.getResBySystem pname ress;

  platforms = builtins.attrNames ress;
  mainProgram = "opencode";
in
  stdenv.mkDerivation rec {
    inherit pname;
    inherit (res) version src;

    sourceRoot = ".";

    nativeBuildInputs = lib.optional stdenv.isLinux autoPatchelfHook;

    buildInputs = [];

    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -D ${mainProgram} $out/bin/${mainProgram}
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
