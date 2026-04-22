{
  lib,
  sources,
  kutils,
  stdenv,
  autoPatchelfHook,
  ...
}: let
  pname = "opencode";

  ress = rec {
    x86_64-linux = sources.opencode-linux-x64;
    aarch64-linux = sources.opencode-linux-arm64;
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
      HOME=$TMPDIR
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
