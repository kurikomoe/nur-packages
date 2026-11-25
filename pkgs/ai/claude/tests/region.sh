#!/usr/bin/env bash
# Run on a Linux host with user namespaces: bash region.sh <built package>
set -euo pipefail
trap 'printf "FAIL %s:%s: %s\n" "$0" "$LINENO" "$BASH_COMMAND" >&2' ERR

case ${1-} in
  check)
    zone=$2 winter=$3 summer=$4
    [[ $TZ == "$zone" && $LANG == de_DE.UTF-8 && $LC_ALL == "$LANG" && $LANGUAGE == de_DE:de ]]
    [[ $(env -u TZ -u TZDIR date -d 2024-01-15T12:00Z +%z) == "$winter" ]]
    [[ $(env -u TZ -u TZDIR date -d 2024-07-15T12:00Z +%z) == "$summer" ]]
    for etc in /etc /etc/static /run/current-system/etc /run/booted-system/etc /nix/var/nix/profiles/system/etc; do
      if [[ -e $etc/localtime || -L $etc/localtime ]]; then
        [[ $(readlink "$etc/localtime") == */"$zone" ]]
        cmp "$etc/localtime" "$TZDIR/$zone"
      fi
      if [[ -f $etc/timezone ]]; then [[ $(<"$etc/timezone") == "$zone" ]]; fi
      for config in "$etc/locale.conf" "$etc/default/locale"; do
        if [[ -f $config ]]; then grep -Fxq "LANG=$LANG" "$config"; fi
      done
    done
    # Explicitly requesting the host's zone must still yield its original rules.
    if [[ $host_tzif == */zoneinfo/* ]]; then [[ $(sha256sum <"$host_tzif") == "$host_hash" ]]; fi
    exit 0 ;;
  inherit-files)
    [[ $(realpath /etc/localtime) == "$host_tzif" && $TZ == "$2" ]]
    if [[ -e /etc/static/localtime ]]; then [[ $(realpath /etc/static/localtime) == "$host_static_tzif" ]]; fi
    exit 0 ;;
esac

out=$(realpath "${1:?pass the built claude-code package}")
script=$(realpath "$0")
export host_tzif host_hash host_static_tzif
host_tzif=$(realpath /etc/localtime)
host_hash=$(sha256sum </etc/localtime)
host_static_tzif=$(realpath -e /etc/static/localtime 2>/dev/null || true)
export LANG=C LC_ALL=C LANGUAGE=C TZ=Etc/UTC
# Exercise Nix glibc's precedence even on hosts with a full locale archive.
export LOCALE_ARCHIVE_2_27=/dev/null
export CLAUDE_NIX_STRICT=0 CLAUDE_NIX_HTTP_ENV=0 CLAUDE_NIX_ENVIRONMENT=1 CLAUDE_NIX_SYSTEM_FILES=1
export CLAUDE_NIX_LOCALE=de_DE.UTF-8
unset CLAUDE_NIX_LANGUAGE
for launcher in claude claude-legacy; do
  # Keep the installed launch chain, substituting a local probe for Claude.
  run=(bwrap --dev-bind / / --ro-bind "$(realpath "$BASH")" "$out/libexec/claude" -- "$out/bin/$launcher" "$script")
  CLAUDE_NIX_TIMEZONE=America/New_York "${run[@]}" check America/New_York -0500 -0400
  CLAUDE_NIX_TIMEZONE=Asia/Tokyo "${run[@]}" check Asia/Tokyo +0900 +0900
  CLAUDE_NIX_TIMEZONE=America/New_York CLAUDE_NIX_SYSTEM_FILES=0 "${run[@]}" inherit-files America/New_York
  CLAUDE_NIX_ENVIRONMENT=0 "${run[@]}" inherit-files Etc/UTC
  echo "PASS $launcher region settings, system selectors and opt-outs"
done
