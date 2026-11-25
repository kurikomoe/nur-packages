#!@bash@
# Deprecated: retained for the claude-legacy entry point. See launcher.py.
set -euo pipefail
source @config@
strict=$1 http=$2 port=$3 proxy=$4
shift 4

if (( strict && http )); then
  # The forwarder dials its targets normally inside the TUN namespace.
  # Start it before exporting proxy variables to avoid a forwarding loop.
  (umask 077; exec "$setsidBin" "$setprivBin" --pdeathsig TERM -- "$tinyproxyBin" -d -c /dev/stdin \
    >>"${CLAUDE_NIX_PROXY_LOG:-/dev/null}" 2>&1) <<<"Port $port
Listen 127.0.0.1
Allow 127.0.0.1
Timeout 600
MaxClients 100
LogLevel Error
DisableViaHeader Yes" &
  helper=$!
  ready=0
  printf -v endpoint '0100007F:%04X' "$port"
  for ((i=0; i<100; i++)); do
    kill -0 "$helper" 2>/dev/null || break
    # Check LISTEN in this private netns without generating a bogus HTTP request.
    while read -r _ address _ state _; do
      if [[ $address == "$endpoint" && $state == 0A ]]; then ready=1; break; fi
    done </proc/net/tcp
    (( !ready )) || break
    "$coreBin/sleep" 0.05
  done
  if (( !ready )); then
    echo "claude: HTTP listener failed to start on 127.0.0.1:$port" >&2
    exit 1
  fi
fi
if (( http )); then
  export http_proxy="$proxy" https_proxy="$proxy" HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy"
  export no_proxy="localhost,127.0.0.1,::1" NO_PROXY="localhost,127.0.0.1,::1"
fi
exec -a @out@/bin/claude-legacy @out@/libexec/claude "$@"
