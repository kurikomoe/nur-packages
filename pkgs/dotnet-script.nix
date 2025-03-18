{
  lib,
  stdenv,
  fetchzip,
  installShellFiles,
  autoPatchelfHook,
}: let
  inherit (stdenv.hostPlatform) system;

  pname = "dotnet-script";
  version = "1.6.0";

  fetch = srcPlatform: hash: let
    args = {
      inherit hash;
      url = "https://github.com/dotnet-script/dotnet-script/releases/download/${version}/dotnet-script.${version}.zip";
      stripRoot = true;
    };
  in
    fetchzip args;

  sources = rec {
    x86_64-linux = fetch "linux_amd64" "sha256-Pc8+hja4OUajMLCOlieVLLvRMj74+OmecYlv3YyOvwo=";
  };

  platforms = builtins.attrNames sources;
  mainProgram = "dotnet-script";
in
  stdenv.mkDerivation rec {
    inherit pname version;

    src =
      if (builtins.elem system platforms)
      then sources.${system}
      else throw "Source for ${pname} is not available for ${system}";

    nativeBuildInputs =
      [
        installShellFiles
      ]
      ++ lib.optional stdenv.isLinux autoPatchelfHook;

    buildInputs = [];

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

    # doInstallCheck = false;
    # installCheckPhase = ''
    #   $out/bin/${mainProgram} --version
    # '';

    meta = with lib; {
      description = "Run C# scripts from the .NET CLI.";
      homepage = "https://github.com/dotnet-script/dotnet-script";
      downloadPage = "https://github.com/dotnet-script/dotnet-script/release";
      inherit mainProgram platforms;
    };
  }
