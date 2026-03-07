{
  pkgs,
  lib,
  sources,
  fetchFromGitHub,
  rustPlatform,
  writeTextFile,
  ...
}: let
  res = sources.shellfirm;
in
  rustPlatform.buildRustPackage rec {
    inherit (res) pname version src;

    nativeBuildInputs = with pkgs; [
      pkg-config
    ];

    buildInputs = with pkgs; [
      openssl
    ];

    OPENSSL_DIR = "${pkgs.openssl.dev}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

    cargoLock.lockFile = "${res.src}/Cargo.lock";

    postInstall = ''
      # === fish plugin ===
      mkdir -p $out/share/fish/vendor_conf.d
      cat > $out/share/fish/vendor_conf.d/shellfirm.fish << EOF
        $out/bin/shellfirm init fish | source
      EOF

      # === bash plugin ===
      mkdir -p $out/share/bash-completion/completions
      cat > $out/share/bash-completion/completions/shellfirm.bash <<EOF
        eval "\$($out/bin/shellfirm init bash)"
      EOF

      # === zsh plugin ===
      mkdir -p $out/share/zsh/site-functions
      cat > $out/share/zsh/site-functions/_shellfirm_init <<EOF
        eval "\$($out/bin/shellfirm init zsh)"
      EOF
    '';

    meta = {
      description = "Intercept any risky patterns (default or defined by you) and prompt you a small challenge for double verification";
      homepage = "https://github.com/kaplanelad/shellfirm";
      license = lib.licenses.asl20;
      maintainers = [];
    };
  }
