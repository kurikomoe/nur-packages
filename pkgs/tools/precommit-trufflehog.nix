{
  lib,
  writeShellScript,
  trufflehog,
  git,
  ...
}: let
  script = writeShellScript "precommit-trufflehog" ''
    set -e
    # ${trufflehog}/bin/trufflehog git "file://$(git rev-parse --show-toplevel)" --since-commit HEAD --results=verified --fail
    ${trufflehog}/bin/trufflehog git file://. --since-commit HEAD --results=verified,unknown --fail
  '';

  output = script.overrideAttrs (final: prev: {
    preferLocalBuild = true;

    buildInputs =
      (prev.buildInputs or [])
      ++ [
        trufflehog
        git
      ];

    meta = {
      description = "scripts for pre-commit";
      homepage = "https://github.com/kurikomoe";
      license = [];
      maintainers = [];
      broken = false;
    };
  });
in
  output
