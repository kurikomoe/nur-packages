#!@bash@
# Deprecated: retained for the claude-legacy entry point. See launcher.py.
set -euo pipefail
source @config@

die() { printf 'claude: %s\n' "$*" >&2; exit 2; }
boolean() {
  case $2 in
    1|yes|true) echo 1 ;;
    0|no|false) echo 0 ;;
    *) die "$1 expects true, false, 1 or 0 (got '$2')" ;;
  esac
}

strict=$(boolean CLAUDE_NIX_STRICT "${CLAUDE_NIX_STRICT-$strictDefault}")
http=$(boolean CLAUDE_NIX_HTTP_ENV "${CLAUDE_NIX_HTTP_ENV-$httpDefault}")
region=$(boolean CLAUDE_NIX_ENVIRONMENT "${CLAUDE_NIX_ENVIRONMENT-$regionDefault}")
files=$(boolean CLAUDE_NIX_SYSTEM_FILES "${CLAUDE_NIX_SYSTEM_FILES-$filesDefault}")
checkCountry=$(boolean CLAUDE_NIX_CHECK_COUNTRY "${CLAUDE_NIX_CHECK_COUNTRY-$checkCountryDefault}")
socks=${CLAUDE_NIX_SOCKS_PROXY-$socksDefault}
proxy=${CLAUDE_NIX_HTTP_PROXY-$httpProxyDefault}
port=${CLAUDE_NIX_HTTP_LISTEN_PORT-$listenDefault}

regionEnv=()
if (( region )); then
  localeName=${CLAUDE_NIX_LOCALE-$localeDefault}
  zone=${CLAUDE_NIX_TIMEZONE-$zoneDefault}
  [[ $localeName =~ ^[a-zA-Z0-9_@.-]+$ ]] || die "invalid locale '$localeName'"
  [[ $zone =~ ^[a-zA-Z0-9_+-]+(/[a-zA-Z0-9_+-]+)*$ && -f $zoneDir/$zone ]] &&
    [[ $("$coreBin/head" -c 4 "$zoneDir/$zone") == TZif ]] || die "unknown time zone '$zone'"
  for key in ${!LC_@}; do unset "$key"; done
  unset LOCPATH
  export LOCALE_ARCHIVE="$localeArchive" LOCALE_ARCHIVE_2_27="$localeArchive"
  diagnostic=$("$coreBin/env" LC_ALL="$localeName" "$localeBin" charmap 2>&1 >/dev/null) && [[ -z $diagnostic ]] ||
    die "locale '$localeName' is unavailable in the packaged glibc locale archive"
  lang=${localeName%%[.@]*}
  languages=${languageDefault:-$lang}
  if [[ -z $languageDefault && $lang == *_* ]]; then languages="$lang:${lang%%_*}"; fi
  export LANGUAGE="${CLAUDE_NIX_LANGUAGE-$languages}"
  [[ $LANGUAGE =~ ^[a-zA-Z0-9_@.:-]+$ ]] || die "invalid LANGUAGE list"
  # This Bash may have already loaded the host's locale archive. Apply the
  # new locale at exec so the new process reads it from the packaged archive.
  regionEnv=("$coreBin/env" "LC_ALL=$localeName" "LANG=$localeName" "TZ=$zone" "TZDIR=$zoneDir")
else
  files=0
fi

net=()
if (( strict || http )); then
  unset http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
fi
if (( strict )); then
  [[ $socks == socks5://?* ]] || die "strict mode requires a socks5:// upstream"
  [[ -c /dev/net/tun && -r /dev/net/tun && -w /dev/net/tun ]] ||
    die "strict mode requires a readable and writable /dev/net/tun"
  net=("$nsproxyBin" -x "$socks" --)
fi
if (( http )); then
  if (( strict )); then
    [[ $port =~ ^[1-9][0-9]{0,4}$ ]] && (( port <= 65535 )) || die "invalid HTTP listen port '$port'"
    proxy="http://127.0.0.1:$port"
  else
    [[ $proxy == http://?* || $proxy == https://?* ]] || die "expected an HTTP(S) proxy URL"
  fi
fi
export DISABLE_AUTOUPDATER=1 DISABLE_INSTALLATION_CHECKS=1 USE_BUILTIN_RIPGREP=0
export PATH="$runtimePath${PATH:+:$PATH}"
proxyLog=${CLAUDE_NIX_PROXY_LOG-}
unset "${!CLAUDE_NIX_@}"
exec "${regionEnv[@]}" "${net[@]}" "$setprivBin" --inh-caps=-all --ambient-caps=-all -- \
  @out@/libexec/session "$strict" "$files" "$http" "$port" "$proxy" "$checkCountry" "$proxyLog" "$@"
