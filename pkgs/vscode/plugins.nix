{
  pkgs,
  lib,
  ...
}: let
  kustomPluginDefs = {
    # "tboox.xmake-vscode" = {
    #   version = "2.4.0";
    #   hash = "sha256-rxx/tG0WqSQoP1nfuknPewDkmEkNBkFBaC2ZrWwTLpg=";
    # };
  };

  kustomPluginList =
    pkgs.vscode-utils.extensionsFromVscodeMarketplace
    (lib.attrsets.mapAttrsToList (
        key: value: let
          keys = builtins.elemAt (lib.strings.splitString "." key);
        in {
          inherit (value) version hash;
          publisher = keys 0;
          name = keys 1;
        }
      )
      kustomPluginDefs);
in {
  libs = with pkgs;
    [
      pkg-config
      icu
      icu.dev
      zlib
    ]
    ++ (pkgs.steam.args.multiPkgs pkgs);

  extensions = with pkgs.vscode-extensions;
  with pkgs.vscode-marketplace;
    [
      # Langs
      rust-lang.rust-analyzer
      tauri-apps.tauri-vscode

      ziglang.vscode-zig

      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.cmake-tools
      ms-vscode.makefile-tools
      xaver.clang-format
      llvm-vs-code-extensions.vscode-clangd
      twxs.cmake
      tboox.xmake-vscode

      ms-python.isort
      ms-python.python
      ms-python.flake8
      ms-python.pylint
      ms-python.vscode-pylance
      ms-python.mypy-type-checker
      ms-python.debugpy
      ms-toolsai.jupyter
      ms-toolsai.jupyter-keymap
      ms-toolsai.jupyter-renderers
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow

      ms-dotnettools.csharp
      ms-dotnettools.csdevkit
      ms-dotnettools.vscodeintellicode-csharp
      ms-dotnettools.vscode-dotnet-runtime

      redhat.java
      vscjava.vscode-java-debug
      vscjava.vscode-java-pack
      vscjava.vscode-gradle
      mathiasfrohlich.kotlin
      vscjava.vscode-maven
      vscjava.vscode-java-dependency
      vscjava.vscode-java-test

      scala-lang.scala

      dbaeumer.vscode-eslint
      ecmel.vscode-html-css
      bradlc.vscode-tailwindcss
      vue.volar
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      denoland.vscode-deno
      zignd.html-css-class-completion
      christian-kohler.npm-intellisense
      sporiley.css-auto-prefix

      blindtiger.masm
      basdp.language-gas-x86
      revng.llvm-ir

      golang.go

      haskell.haskell
      justusadam.language-haskell

      james-yu.latex-workshop
      yzhang.markdown-all-in-one

      bbenoist.nix
      jnoortheen.nix-ide
      zxh404.vscode-proto3
      skellock.just
      nefrob.vscode-just-syntax
      thenuprojectcontributors.vscode-nushell-lang
      ms-azuretools.vscode-docker
      tamasfe.even-better-toml
      redhat.vscode-xml
      redhat.vscode-yaml
      dotjoshjohnson.xml
      mrmlnc.vscode-json5
      andyyaldoo.vscode-json
      ms-vscode.powershell
      andrejunges.handlebars

      # LSP
      visualstudioexptteam.vscodeintellicode
      visualstudioexptteam.intellicode-api-usage-examples

      # Editor
      vscodevim.vim
      oderwat.indent-rainbow
      esbenp.prettier-vscode
      shardulm94.trailing-spaces
      mechatroner.rainbow-csv
      foxundermoon.shell-format
      aaron-bond.better-comments
      continue.continue
      usernamehw.errorlens
      evan-buss.font-switcher
      wayou.vscode-todo-highlight
      vincaslt.highlight-matching-tag
      kisstkondoros.vscode-gutter-preview
      wmaurer.change-case
      editorconfig.editorconfig
      tyriar.sort-lines

      # Git
      waderyan.gitblame
      donjayamanne.githistory
      github.vscode-github-actions
      eamodio.gitlens
      github.vscode-pull-request-github

      # Env
      mkhl.direnv
      arrterian.nix-env-selector

      ms-vscode-remote.remote-wsl
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-ssh-edit
      ms-vscode-remote.remote-containers
      ms-vscode-remote.vscode-remote-extensionpack

      # Themes
      pkief.material-icon-theme
      arcticicestudio.nord-visual-studio-code
      zhuangtongfa.material-theme
      emmanuelbeziat.vscode-great-icons

      # Misc
      christian-kohler.path-intellisense
      wakatime.vscode-wakatime
      ms-vscode.hexeditor
      ryu1kn.partial-diff
      humao.rest-client
      alefragnani.project-manager
      adpyke.codesnap
      chrmarti.regex

      # AI
      github.copilot-chat
      github.copilot
    ]
    ++ kustomPluginList;
}
