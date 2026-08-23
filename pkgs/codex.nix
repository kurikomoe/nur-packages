{
  lib,
  sources,
  kutils,
  stdenvNoCC,
  makeBinaryWrapper,
  bubblewrap,
  ripgrep,
  ...
}: let
  pname = "codex";

  ress = rec {
    x86_64-linux = sources.codex;
  };
  res = kutils.getResBySystem pname ress;

  runnerRess = rec {
    x86_64-linux = sources.codex-host-runner;
  };
  runnerRes = kutils.getResBySystem "codex-host-runner" runnerRess;

  platforms = builtins.attrNames ress;
  mainProgram = "codex";
  hostRunnerProgram = "codex-code-mode-host";
in
  stdenvNoCC.mkDerivation rec {
    inherit pname;
    inherit (res) version;

    srcs = [res.src runnerRes.src];

    sourceRoot = ".";
    nativeBuildInputs = [makeBinaryWrapper];

    installPhase = ''
      runHook preInstall
      install -Dm755 ${mainProgram}-x86_64-unknown-linux-musl $out/libexec/${mainProgram}
      makeBinaryWrapper $out/libexec/${mainProgram} $out/bin/${mainProgram} \
        --prefix PATH : ${lib.makeBinPath [ripgrep bubblewrap]}

      install -Dm755 codex-code-mode-host-x86_64-unknown-linux-musl $out/libexec/${hostRunnerProgram}
      makeBinaryWrapper $out/libexec/${hostRunnerProgram} $out/bin/${hostRunnerProgram} \
        --prefix PATH : ${lib.makeBinPath [ripgrep bubblewrap]}
      runHook postInstall
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      HOME=$TMPDIR
      $out/bin/${mainProgram} --version
      test -x $out/bin/${hostRunnerProgram}
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
