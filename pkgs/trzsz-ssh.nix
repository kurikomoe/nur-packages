{
  lib,
  system,
  sources,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  zenity,
  tmux,
  openssh,
  go,
  ...
}: let
  trzsz-ssh = buildGoModule rec {
    inherit (sources.trzsz-ssh) pname version src;

    nativeBuildInputs = [go makeWrapper];
    buildInputs = [trzsz zenity tmux openssh];

    buildPhase = ''
      go build -o bin/tssh ./cmd/tssh
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm755 bin/tssh -t $out/bin/
      runHook postInstall
    '';

    fixupPhase = ''
      wrapProgram "$out/bin/tssh" \
        --set PATH ${lib.makeBinPath buildInputs}
    '';

    vendorHash = "sha256-pI9BlttS9a1XrgBBmUd+h529fLbsbwSMwjKn4P50liE=";
    # latest vesion: https://github.com/trzsz/trzsz-ssh
  };

  trzsz = buildGoModule rec {
    inherit (sources.trzsz) pname version src;

    nativeBuildInputs = [go makeWrapper];
    buildInputs = [zenity tmux];

    buildPhase = ''
      go build -o bin/trzsz ./cmd/trzsz
      go build -o bin/tsz ./cmd/tsz
      go build -o bin/trz ./cmd/trz
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm755 bin/* -t $out/bin/
      runHook postInstall
    '';

    fixupPhase = ''
      for exe in trz tsz trzsz; do
        wrapProgram "$out/bin/$exe" \
          --set PATH ${lib.makeBinPath buildInputs}
      done
    '';

    vendorHash = "sha256-AsrRHHBlzW5s/PtJSQ+hAgqUIYwDwoemQaerRV/QKX0=";
    # latest vesion: https://github.com/trzsz/trzsz-go
  };
in {
  recurseForDerivations = true;
  inherit trzsz trzsz-ssh;
}
