# nur-packages

**My personal [NUR](https://github.com/nix-community/NUR) repository**

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/kurikomoe/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)

[![Cachix Cache](https://img.shields.io/badge/cachix-kurikomoe-blue.svg)](https://<YOUR_CACHIX_CACHE_NAME>.cachix.org)

## dsh-tui

`dsh-tui` 包提供 `dsh-tui`、`dst` 和 `dsh`，并携带 Node.js、pnpm。单独使用 CLI 时也可以安装 `dsh` 包。

Nix 固定 CLI 和全局启动器；首次启动需要联网，通过 pnpm 在 `$DSH_HOME/profiles/dsh-tui`（默认 `~/.dsh/profiles/dsh-tui`）安装对应版本的 TUI。profile、插件和用户配置保持可写，可以继续通过 `dsh plugin --profile dsh-tui add <package>`、`remove <package>` 管理插件。启动器和 CLI 的升级通过 Nix 完成。

启动器及其派生的 Node 进程使用相同的内部模块兼容处理。实现参考 [dsh-nix](https://github.com/Samuka007/dsh-nix)，使用 npm 发布产物和锁定依赖，保留上游的默认启动路径和可变 profile 流程。

nvfetcher 更新源之后执行 `./nix-update.sh dsh-tui`，脚本会自动刷新 dsh 锁文件和依赖哈希，并验证 dsh、dsh-tui 构建。单独更新 CLI 可执行 `./nix-update.sh dsh`；不带参数时更新脚本中的全部目标。
