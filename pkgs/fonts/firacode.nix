{
  lib,
  sources,
  stdenvNoCC,
  unzip,
  ...
}: let
  res = sources.font-firacode;
in
  stdenvNoCC.mkDerivation rec {
    inherit (res) pname version src;

    nativeBuildInputs = [
      unzip
    ];

    unpackPhase = ''
      export sourceRoot=$TMPDIR/source
      mkdir -p $sourceRoot
      unzip $src -d $sourceRoot
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 $sourceRoot/ttf/*.ttf -t $out/share/fonts/FiraCode/
      runHook postInstall
    '';

    meta = {
      description = "Free monospaced font with programming ligatures";
      homepage = "https://github.com/tonsky/FiraCode";
      license = lib.licenses.ofl;
      platforms = lib.platforms.all;
    };
  }
