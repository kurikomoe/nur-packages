{
  lib,
  sources,
  kutils,
  stdenvNoCC,
  autoPatchelfHook,
  rustPlatform,
  python3,
  bash,
  coreutils,
  curl,
  glibc,
  glibcLocales,
  tzdata,
  bubblewrap,
  socat,
  ripgrep,
  procps,
  tinyproxy,
  util-linux,
  writeText,
  network ? {},
  environment ? {},
  ...
}: let
  release = kutils.getResBySystem "claude-code" {x86_64-linux = sources.claude-code;};
  nsproxy = rustPlatform.buildRustPackage {
    inherit (sources.nsproxy-rs) pname src;
    version = sources.nsproxy-rs.date;
    cargoLock = sources.nsproxy-rs.cargoLock."Cargo.lock";
    patches = [./preserve-ssh-config.patch];
    # The upstream path-validation tests stat both resolver files, which
    # the Nix build sandbox need not provide. Give only the tests a fixture.
    postPatch = ''
      substituteInPlace src/namespace.rs --replace-fail \
        'const INTERNAL_BIND_TARGETS: [&str; 2]' \
        '#[cfg(test)]
      const INTERNAL_BIND_TARGETS: [&str; 2] = [concat!(env!("CARGO_MANIFEST_DIR"), "/test-resolv.conf"), concat!(env!("CARGO_MANIFEST_DIR"), "/test-nsswitch.conf")];
      #[cfg(not(test))]
      const INTERNAL_BIND_TARGETS: [&str; 2]'
      substituteInPlace src/namespace.rs --replace-fail \
        '"source-one:/etc/resolv.conf".to_owned()' \
        'format!("source-one:{}", INTERNAL_BIND_TARGETS[0])'
      touch test-resolv.conf test-nsswitch.conf
    '';
  };
  net =
    {
      strict = true;
      httpEnv = true;
      socksProxy = "socks5://127.0.0.1:8899";
      httpProxy = "http://127.0.0.1:8899";
      httpListenPort = 8899;
    }
    // network;
  region =
    {
      enable = true;
      systemFiles = true;
      checkCountry = true;
      locale = "en_US.UTF-8";
      language = null; # Derived from the effective locale when unset.
      timeZone = "Asia/Tokyo";
    }
    // environment;
  defaults = {
    strictDefault = lib.boolToString net.strict;
    httpDefault = lib.boolToString net.httpEnv;
    regionDefault = lib.boolToString region.enable;
    filesDefault = lib.boolToString region.systemFiles;
    checkCountryDefault = lib.boolToString region.checkCountry;
    socksDefault = net.socksProxy;
    httpProxyDefault = net.httpProxy;
    listenDefault = toString net.httpListenPort;
    localeDefault = region.locale;
    languageDefault =
      if region.language == null
      then ""
      else lib.concatStringsSep ":" region.language;
    zoneDefault = region.timeZone;
    zoneDir = "${tzdata}/share/zoneinfo";
    localeArchive = "${glibcLocales}/lib/locale/locale-archive";
    localeBin = "${lib.getBin glibc}/bin/locale";
    curlBin = "${lib.getExe curl}";
    nsproxyBin = "${nsproxy}/bin/nsproxy";
    tinyproxyBin = "${tinyproxy}/bin/tinyproxy";
    bwrapBin = "${bubblewrap}/bin/bwrap";
    setprivBin = "${util-linux}/bin/setpriv";
    runtimePath = lib.makeBinPath [ripgrep procps socat bubblewrap];
    coreBin = "${coreutils}/bin";
    setsidBin = "${util-linux}/bin/setsid";
  };
  legacyConfig = writeText "claude-legacy-defaults" (lib.toShellVars defaults);
  jsonConfig = writeText "claude-session-defaults.json" (builtins.toJSON defaults);
in
  stdenvNoCC.mkDerivation {
    pname = "claude-code";
    inherit (release) version src;
    dontUnpack = true;
    dontStrip = true;
    nativeBuildInputs = [autoPatchelfHook];
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/libexec/claude"
      mkdir -p "$out/bin"
      substitute ${./launcher.py} "$out/bin/claude" \
        --replace-fail '@python@' '${python3.interpreter}' \
        --replace-fail '@jsonConfig@' '${jsonConfig}' \
        --replace-fail '@out@' "$out"
      chmod +x "$out/bin/claude"
      ln -s ../bin/claude "$out/libexec/claude-session"
      ln -s ../bin/claude "$out/libexec/claude-run"
      ln -s ../bin/claude "$out/libexec/claude-check-country"

      for spec in 'launch.sh bin/claude-legacy' 'session.sh libexec/session' 'run.sh libexec/run'; do
        read -r srcName dest <<< "$spec"
        substitute "${./.}/$srcName" "$out/$dest" \
          --replace-fail '@bash@' '${bash}/bin/bash' \
          --replace-fail '@config@' '${legacyConfig}' \
          --replace-fail '@out@' "$out"
        chmod +x "$out/$dest"
      done
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      ${python3.interpreter} -I ${./tests/country.py} "$out/bin/claude"
      for launcher in claude claude-legacy; do
        HOME="$TMPDIR" CLAUDE_NIX_STRICT=0 CLAUDE_NIX_HTTP_ENV=0 CLAUDE_NIX_SYSTEM_FILES=0 CLAUDE_NIX_CHECK_COUNTRY=0 \
          "$out/bin/$launcher" --version | grep -F "$version"
      done
      runHook postInstallCheck
    '';
    meta = {
      description = "Claude Code with per-session IPv4 proxy and locale settings";
      homepage = "https://code.claude.com/";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "claude";
    };
  }
