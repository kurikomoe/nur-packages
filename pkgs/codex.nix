{
  lib,
  sources,
  kutils,
  stdenvNoCC,
  autoPatchelfHook,
  ncurses,
  zstd,
  ...
}: let
  pname = "codex";

  ress = rec {
    x86_64-linux = sources.codex;
  };
  res = kutils.getResBySystem pname ress;

  platforms = builtins.attrNames ress;
  mainProgram = "codex";
  hostRunnerProgram = "codex-code-mode-host";
in
  stdenvNoCC.mkDerivation rec {
    inherit pname;
    inherit (res) version;

    src = res.src;

    sourceRoot = "source";
    nativeBuildInputs = [autoPatchelfHook zstd];
    buildInputs = [ncurses];
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      mkdir source
      tar -xf "$src" -C source
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      # Keep the package layout so Codex can locate all bundled resources.
      mkdir -p "$out"
      cp -a . "$out/"
      runHook postInstall
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      export HOME="$TMPDIR"
      $out/bin/${mainProgram} --version
      test -x $out/bin/${hostRunnerProgram}
      $out/codex-path/rg --version
      $out/codex-resources/bwrap --version
      $out/codex-resources/zsh/bin/zsh --version
      # The voice host has no CLI help mode; check its dynamic dependencies.
      voiceHost="$out/codex-resources/voice/bin/codex-voice-host"
      test -x "$voiceHost"
      voiceInterpreter=$(patchelf --print-interpreter "$voiceHost")
      "$voiceInterpreter" --list "$voiceHost"
      # Ensure every file from the complete archive is installed.
      while IFS= read -r -d $'\0' file; do
        test -f "$out/$file"
      done < <(find . -type f -print0)
      runHook postInstallCheck
    '';

    meta = with lib; {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      downloadPage = "https://github.com/openai/codex/releases";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      license = licenses.asl20;
      inherit mainProgram platforms;
    };
  }
