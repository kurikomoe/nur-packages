{
  lib,
  sources,
  inputs,
  kutils,
  stdenv,
  autoPatchelfHook,
  ...
}: let
  inherit (stdenv.hostPlatform) system;

  res = sources.opencode;

  flake = import inputs.flake-compat {
    inherit system;
    src = res.src;
  };

  opencode = flake.defaultNix.packages.${system}.default;
in
  opencode.overrideAttrs (final: prev: {
    meta = with lib; {
      description = "AI-powered coding agent for the terminal";
      homepage = "https://opencode.ai";
      downloadPage = "https://github.com/anomalyco/opencode/releases";
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      license = licenses.mit;
    };
  })
# stdenv.mkDerivation rec {
#   inherit pname;
#   inherit (res) version src;
#
#   sourceRoot = ".";
#
#   nativeBuildInputs = lib.optional stdenv.isLinux autoPatchelfHook;
#
#   buildInputs = [];
#
#   dontStrip = true;
#
#   installPhase = ''
#     runHook preInstall
#     install -D ${mainProgram} $out/bin/${mainProgram}
#     runHook postInstall
#   '';
#
#   doInstallCheck = true;
#
#   installCheckPhase = ''
#     HOME=$TMPDIR
#     $out/bin/${mainProgram} --version
#   '';
#
#   meta = with lib; {
#     description = "AI-powered coding agent for the terminal";
#     homepage = "https://opencode.ai";
#     downloadPage = "https://github.com/anomalyco/opencode/releases";
#     sourceProvenance = with sourceTypes; [binaryNativeCode];
#     license = licenses.mit;
#     inherit mainProgram platforms;
#   };
# }

