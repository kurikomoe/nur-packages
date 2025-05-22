{
  lib,
  stdenv,
  sources,
  dotnet-runtime,
  installShellFiles,
  autoPatchelfHook,
  ...
}: let
  res = sources.dotnet-script;
  mainProgram = "dotnet-script";
in
  stdenv.mkDerivation rec {
    inherit (res) pname version src;

    nativeBuildInputs =
      [
        installShellFiles
      ]
      ++ lib.optional stdenv.isLinux autoPatchelfHook;

    buildInputs = [
      dotnet-runtime
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/share

      cp -r . $out/share

      ln -sf $out/share/${mainProgram}.sh $out/bin/${mainProgram}

      patchShebangs $out/bin/${mainProgram}
      chmod +x $out/bin/${mainProgram}

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/${mainProgram} --version
    '';

    meta = with lib; {
      description = "Run C# scripts from the .NET CLI.";
      homepage = "https://github.com/dotnet-script/dotnet-script";
      downloadPage = "https://github.com/dotnet-script/dotnet-script/release";
      inherit mainProgram;
    };
  }
