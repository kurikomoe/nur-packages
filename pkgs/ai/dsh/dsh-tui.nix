{
  lib,
  sources,
  stdenvNoCC,
  nodejs,
  pnpm,
  dsh,
  stdenv,
  makeWrapper,
  ...
}: let
  res = sources.dsh-tui;
in
  stdenvNoCC.mkDerivation {
    pname = "dsh-tui";
    inherit (res) version src;

    nativeBuildInputs = [makeWrapper];
    dontBuild = true;

    # Upstream's global entry is a dependency-free launcher. It installs the
    # matching TUI and its dependencies into a writable DSH profile on first
    # launch, then delegates to that copy. Keep this plugin/update workflow.
    installPhase = ''
      runHook preInstall
      packageDir="$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"
      mkdir -p "$packageDir" "$out/bin"
      cp -a . "$packageDir/"
      # The private Node wrapper also covers delegated profile/host processes.
      makeWrapper ${dsh}/libexec/dsh-node "$out/bin/dsh-tui" \
        --add-flags "$packageDir/bin/dsh-tui.js" \
        --prefix PATH : ${lib.makeBinPath [dsh nodejs pnpm]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [stdenv.cc.cc.lib]}
      ln -s dsh-tui "$out/bin/dst"
      ln -s ${lib.getExe dsh} "$out/bin/dsh"
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/dsh-tui" version
      "$out/bin/dst" help
      runHook postInstallCheck
    '';

    passthru = {inherit dsh;};

    meta = with lib; {
      description = "Interactive terminal interface for DeepSeek Harness";
      homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
      license = licenses.mit;
      mainProgram = "dsh-tui";
      inherit (dsh.meta) platforms;
    };
  }
