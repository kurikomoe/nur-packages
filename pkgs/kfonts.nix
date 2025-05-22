{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "kfonts";
  version = "1.0.0";

  src = ../res/fonts;

  installPhase = ''
    runHook preInstall

    install -Dm644 *.ttc -t $out/share/fonts/
    install -Dm644 *.ttf -t $out/share/fonts/

    runHook postInstall
  '';

  meta = {
    description = "Kuriko's font collection";
    homepage = "https://github.com/kurikomoe/nur-packages";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
