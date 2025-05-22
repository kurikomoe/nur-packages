{
  lib,
  sources,
  kutils,
  stdenv,
  fetchzip,
  installShellFiles,
  autoPatchelfHook,
  ...
}: let
  pname = "1password-cli";

  ress = rec {
    x86_64-linux = sources."1password-cli-linux";
  };

  res = kutils.getResBySystem pname ress;

  platforms = builtins.attrNames ress;
  mainProgram = "op";
in
  stdenv.mkDerivation rec {
    inherit pname;
    inherit (res) version src;

    nativeBuildInputs = [installShellFiles] ++ lib.optional stdenv.isLinux autoPatchelfHook;

    buildInputs = [];

    installPhase = ''
      runHook preInstall
      install -D ${mainProgram} $out/bin/${mainProgram}
      runHook postInstall
    '';

    postInstall = ''
      HOME=$TMPDIR
      installShellCompletion --cmd ${mainProgram} \
        --bash <($out/bin/${mainProgram} completion bash) \
        --fish <($out/bin/${mainProgram} completion fish) \
        --zsh <($out/bin/${mainProgram} completion zsh)
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      $out/bin/${mainProgram} --version
    '';

    meta = with lib; {
      description = "1Password command-line tool";
      homepage = "https://developer.1password.com/docs/cli/";
      downloadPage = "https://app-updates.agilebits.com/product_history/CLI2";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      license = licenses.unfree;
      inherit mainProgram platforms;
    };
  }
