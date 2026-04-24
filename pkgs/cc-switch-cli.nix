{
  lib,
  sources,
  kutils,
  stdenv,
  autoPatchelfHook,
  ...
}: let
  pname = "cc-switch-cli";

  ress = rec {
    x86_64-linux = sources.cc-switch-cli;
  };

  res = kutils.getResBySystem pname ress;

  platforms = builtins.attrNames ress;
  mainProgram = "cc-switch";
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
      description = "Switch between Claude Code providers from the terminal";
      homepage = "https://github.com/SaladDay/cc-switch-cli";
      downloadPage = "https://github.com/SaladDay/cc-switch-cli/releases";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      license = licenses.mit;
      inherit mainProgram platforms;
    };
  }
