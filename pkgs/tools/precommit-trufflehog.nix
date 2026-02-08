{
  lib,
  writeShellApplication,
  trufflehog,
  git,
  ...
}:
writeShellApplication {
  name = "precommit-trufflehog";

  runtimeInputs = [git trufflehog];

  text = ''
    trufflehog git "file://$(git rev-parse --show-toplevel)" \
      --since-commit HEAD \
      --results=unverified,verified,unknown \
      --fail --trust-local-git-config
  '';

  meta = {
    description = "scripts for pre-commit";
    homepage = "https://github.com/kurikomoe";
    mainProgram = "precommit-trufflehog";
  };
}
