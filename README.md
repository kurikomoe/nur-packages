# nur-packages

**My personal [NUR](https://github.com/nix-community/NUR) repository**

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/kurikomoe/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)

[![Cachix Cache](https://img.shields.io/badge/cachix-kurikomoe-blue.svg)](https://<YOUR_CACHIX_CACHE_NAME>.cachix.org)

## Claude Code

`nix run .#claude-code` 在当前目录运行 Claude。默认同时开启 IPv4 TCP 透明代理与 HTTP 代理变量。需要 Linux 用户命名空间、可读写的 `/dev/net/tun` 和宿主 `127.0.0.1:8899` 上的 SOCKS5 服务。普通对外 UDP 与 IPv6 无出口，域名经代理解析。会话内的 `localhost` 指向独立命名空间，因此依赖宿主回环服务或浏览器回调的工作流需要单独安排。

| 包参数（支持 `.override`） | 单次启动变量 | 默认值 |
|---|---|---|
| `network.strict` / `network.httpEnv` | `CLAUDE_NIX_STRICT` / `CLAUDE_NIX_HTTP_ENV` | 均开启 |
| `network.socksProxy` | `CLAUDE_NIX_SOCKS_PROXY` | `socks5://127.0.0.1:8899` |
| `network.httpProxy`（仅开启 HTTP 变量时） | `CLAUDE_NIX_HTTP_PROXY` | `http://127.0.0.1:8899` |
| `network.httpListenPort`（双开时） | `CLAUDE_NIX_HTTP_LISTEN_PORT` | `8899` |
| `environment.enable` / `environment.systemFiles` | `CLAUDE_NIX_ENVIRONMENT` / `CLAUDE_NIX_SYSTEM_FILES` | 均开启 |
| `environment.checkCountry` | `CLAUDE_NIX_CHECK_COUNTRY` | 开启 |
| `environment.locale` / `environment.timeZone` | `CLAUDE_NIX_LOCALE` / `CLAUDE_NIX_TIMEZONE` | `en_US.UTF-8` / `Asia/Tokyo` |
| `environment.language`（语言列表） | `CLAUDE_NIX_LANGUAGE`（冒号分隔） | 从 locale 推导 |

例如 `CLAUDE_NIX_STRICT=0 claude` 使用宿主 HTTP 代理。两个网络开关都设为 0 时继承调用者网络环境。地区配置独立生效，覆盖会话内的 libc locale、gettext、时区以及常用系统配置文件。关闭 `systemFiles` 可仅设置环境变量。项目文件和宿主帐号仍可能包含地区信息。

每次启动时，包装器在会话网络和代理就绪后，通过 HTTPS 请求 `api.anthropic.com/cdn-cgi/trace`，将返回的出口国家码与 IANA `zone.tab` 中的时区国家比较。同一国家的时区均可，例如美国出口可以配 `America/New_York` 或 `America/Los_Angeles`。国家不符、查询超时（8 秒）或无法判定国家时，启动器报错退出。检查只采样该域名本次请求的出口，使用自定义 API 域名和代理分流时需考虑各域名的路由。

地区覆盖关闭时仍会检查继承的 `TZ`；未设置 `TZ` 时从 `/etc/localtime` 的 zoneinfo 链接取名。请选择 `zone.tab` 中的地理名称，比如 `Asia/Tokyo`。离线运行或使用 `Etc/UTC` 等无国家的时区时，可以显式设置 `CLAUDE_NIX_CHECK_COUNTRY=0`。两个入口都会在解析选项后清理包装器专用的 `CLAUDE_NIX_*` 环境变量。Claude 和子进程仍会获得生效的 `TZ`、locale、代理变量和用户传入的 Claude 配置。

在 NixOS 上，会话内的 `/etc/localtime`、`/etc/static` 及当前、启动和系统 profile 的 `etc` 目录使用同一套地区设置。清除 `TZ` 后，程序仍能从系统时区文件取得正确的夏令时规则。直接查询宿主服务时，得到的是该服务自己的设置。

Claude 内置 sandbox 继续执行域名策略。对经过上游代理的连接，最终解析域名的代理需负责检查受限本地地址。通过 Docker、Nix daemon 等宿主服务代发的流量遵循该服务的网络策略。[Claude sandbox 网络说明](https://code.claude.com/docs/en/sandboxing#network-isolation)

默认入口使用仅依赖标准库的 [Python 启动器](pkgs/ai/claude/launcher.py)。原 Bash 启动器已标记 deprecated，安装后可调用 `claude-legacy`。两个入口使用同一组配置。Python 源码使用 `ruff format` 排版。

同时启用严格代理和 HTTP 环境变量时，Tinyproxy 使用独立的进程会话，默认丢弃它的运行日志。Claude 的 TUI 和标准错误照常显示。需要诊断时可指定可写文件，例如 `CLAUDE_NIX_PROXY_LOG="$HOME/claude-proxy.log" claude`。日志追加到该文件，代理启动失败仍由启动器直接报错。

## dsh-tui

`dsh-tui` 包提供 `dsh-tui`、`dst` 和 `dsh`，并携带 Node.js、pnpm。单独使用 CLI 时也可以安装 `dsh` 包。

Nix 固定 CLI 和全局启动器；首次启动需要联网，通过 pnpm 在 `$DSH_HOME/profiles/dsh-tui`（默认 `~/.dsh/profiles/dsh-tui`）安装对应版本的 TUI。profile、插件和用户配置保持可写，可以继续通过 `dsh plugin --profile dsh-tui add <package>`、`remove <package>` 管理插件。启动器和 CLI 的升级通过 Nix 完成。

启动器及其派生的 Node 进程使用相同的内部模块兼容处理。实现参考 [dsh-nix](https://github.com/Samuka007/dsh-nix)，使用 npm 发布产物和锁定依赖，保留上游的默认启动路径和可变 profile 流程。

nvfetcher 更新源之后执行 `./nix-update.sh dsh-tui`，脚本会自动刷新 dsh 锁文件和依赖哈希，并验证 dsh、dsh-tui 构建。单独更新 CLI 可执行 `./nix-update.sh dsh`；不带参数时更新脚本中的全部目标。
