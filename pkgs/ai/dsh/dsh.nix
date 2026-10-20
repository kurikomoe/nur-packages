{
  lib,
  sources,
  buildNpmPackage,
  nodejs,
  pnpm,
  autoPatchelfHook,
  stdenv,
  makeWrapper,
  ...
}: let
  res = sources.dsh;
in
  buildNpmPackage {
    pname = "dsh";
    inherit (res) version src;

    npmDepsHash = "sha256-KgBeqShDUqd3wyLl+GgYMBmUhv8YB3WIirpTYF8NYvI=";
    npmFlags = ["--ignore-scripts"];
    dontNpmBuild = true;

    nativeBuildInputs = [autoPatchelfHook makeWrapper];
    buildInputs = [stdenv.cc.cc.lib];

    # The npm release already contains compiled JavaScript. Its development
    # dependencies and repository-only lifecycle scripts are not shipped.
    postPatch = ''
      ${nodejs}/bin/node -e '
        const fs = require("node:fs");
        const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
        delete pkg.devDependencies;
        delete pkg.scripts;
        fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
      '
      cp ${./package-lock.json} package-lock.json
    '';

    postConfigure = ''
      node node_modules/@deepseek-ai/dsh-subprocess-local/scripts/ensure-spawn-helper.mjs
    '';

    postInstall = ''
      # Koffi also bundles musl variants, which are unused by Nix's glibc Node.
      rm -rf "$out/lib/node_modules/@deepseek-ai/dsh/node_modules/@koromix"/koffi-linux-*/musl_*
      rm "$out/bin/dsh"
      mkdir -p "$out/libexec"
      makeWrapper ${nodejs}/bin/node "$out/libexec/dsh-node" \
        --add-flags --expose-internals \
        --set DSH_NODE_EXECUTABLE "$out/libexec/dsh-node" \
        --prefix PATH : ${lib.makeBinPath [nodejs pnpm]} \
        --prefix NODE_OPTIONS " " --require=${./node-internals.cjs} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [stdenv.cc.cc.lib]}
      makeWrapper "$out/libexec/dsh-node" "$out/bin/dsh" \
        --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/dsh" --version
      "$out/bin/dsh" --help
      "$out/libexec/dsh-node" -e '
        const check = () => {
          const requireFromDsh = require("node:module").createRequire(process.argv[1]);
          const { requireBuiltin } = requireFromDsh("node-addon-require-builtin");
          const loader = requireBuiltin("internal/modules/esm/loader");
          if (typeof loader.getOrInitializeCascadedLoader !== "function") process.exit(1);
        };
        const result = require("node:child_process").spawnSync(
          process.execPath, ["-e", `(''${check})()`, process.argv[1]], {stdio: "inherit"}
        );
        process.exit(result.status ?? 1);
      ' "$out/lib/node_modules/@deepseek-ai/dsh/package.json"
      ${nodejs}/bin/node -e '
        const pty = require(process.argv[1]);
        const terminal = pty.spawn(process.argv[2], ["-c", "printf dsh-pty-ok"]);
        let output = "";
        const timer = setTimeout(() => process.exit(1), 10000);
        terminal.onData(data => { output += data; });
        terminal.onExit(({exitCode}) => {
          clearTimeout(timer);
          process.exit(exitCode === 0 && output.includes("dsh-pty-ok") ? 0 : 1);
        });
      ' "$out/lib/node_modules/@deepseek-ai/dsh/node_modules/node-pty" ${stdenv.shell}
      runHook postInstallCheck
    '';

    meta = with lib; {
      description = "DeepSeek Harness CLI";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = licenses.mit;
      mainProgram = "dsh";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  }
