#!@bash@
# Deprecated: retained for the claude-legacy entry point. See launcher.py.
set -euo pipefail
source @config@
strict=$1 files=$2 http=$3 port=$4 proxy=$5 checkCountry=$6 proxyLog=$7
shift 7
view=()

# Rebuild only the directory entries that contain an override. Retaining
# other symlinks verbatim also preserves NixOS /etc/static indirection.
mirror_etc() {
  local root=$1 dir=${2:-$1} entry mount=--bind
  [[ $root == /etc ]] || mount=--ro-bind
  view+=(--perms 0755 --tmpfs "$dir")
  for entry in "$dir"/*; do
    case $entry in
      /etc/resolv.conf|/etc/nsswitch.conf)
        if (( strict )); then
          # nsproxy unlinks its private resolver files after mounting them.
          # Copy the open file; rebinding its deleted pathname fails.
          exec {resolverFd}<"$entry"
          view+=(--ro-bind-data "$resolverFd" "$entry")
          continue
        fi ;;
      "$root/localtime") continue ;;
      "$root/timezone")
        exec {zoneFd}<<<"$TZ"
        view+=(--ro-bind-data "$zoneFd" "$entry")
        continue ;;
      "$root/locale.conf"|"$root/default/locale")
        exec {langFd}<<<"$(printf 'LANG=%s\nLC_ALL=%s\nLANGUAGE=%s' "$LANG" "$LC_ALL" "$LANGUAGE")"
        view+=(--ro-bind-data "$langFd" "$entry")
        continue ;;
      "$root/default")
        if [[ -e $entry/locale || -L $entry/locale ]]; then
          mirror_etc "$root" "$entry"
          continue
        fi ;;
    esac
    if [[ -L $entry ]]; then
      view+=(--symlink "$("$coreBin/readlink" "$entry")" "$entry")
    else
      view+=("$mount" "$entry" "$entry")
    fi
  done
  if [[ $dir == "$root" && ( $root == /etc || -e $root/localtime || -L $root/localtime ) ]]; then
    view+=(--symlink "$zoneDir/$TZ" "$root/localtime")
  fi
  view+=(--remount-ro "$dir")
}
if (( files )); then
  shopt -s dotglob nullglob
  mirror_etc /etc
  if [[ -f /etc/NIXOS ]]; then
    declare -A seen=([/etc]=1)
    for alias in /etc/static /run/current-system/etc /run/booted-system/etc /nix/var/nix/profiles/system/etc; do
      [[ -d $alias ]] || continue
      tree=$("$coreBin/realpath" -e "$alias")
      [[ -z ${seen["$tree"]-} ]] || continue
      seen["$tree"]=1
      mirror_etc "$tree"
    done
  fi
fi
if (( strict )); then
  # These filesystem sockets can ask a host process to resolve names,
  # even though the session has its own network namespace and resolver.
  for socket in /run/nscd/socket /run/systemd/resolve/io.systemd.Resolve; do
    [[ ! -S $socket ]] || view+=(--ro-bind /dev/null "$socket")
  done
fi
if (( ${#view[@]} )); then
  view=("$bwrapBin" --dev-bind / / "${view[@]}" --chdir "$PWD" --)
fi
exec "${view[@]}" @out@/libexec/run "$strict" "$http" "$port" "$proxy" "$checkCountry" "$proxyLog" "$@"
