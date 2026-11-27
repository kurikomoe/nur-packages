#!@python@ -IS
"""Launch Claude on the host, enter its mount view, then start the application."""

import json
import os
import re
import signal
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

OUT = Path("@out@")
LIBEXEC = OUT / "libexec"
DEFAULTS = json.loads(Path("@jsonConfig@").read_text())
PROXY_VARS = ("http_proxy", "https_proxy", "all_proxy", "no_proxy")


def option(name: str, default: str) -> str:
    return os.environ.get("CLAUDE_NIX_" + name, default)


def switch(name: str, default: str) -> bool:
    value = option(name, default)
    if value in ("1", "yes", "true"):
        return True
    if value in ("0", "no", "false"):
        return False
    raise ValueError(f"CLAUDE_NIX_{name} expects a boolean, got {value!r}")


@dataclass(frozen=True)
class Session:
    # Only these resolved options cross the exec boundaries. Claude's own
    # arguments always travel as a separate, untouched argv list.
    strict: bool
    system_files: bool
    http_proxy: str | None
    listen_port: int | None
    check_country: bool
    proxy_log: str | None


def configure_region() -> bool:
    """Set the process locale and time zone, and return whether to mirror /etc."""
    enabled = switch("ENVIRONMENT", DEFAULTS["regionDefault"])
    files = switch("SYSTEM_FILES", DEFAULTS["filesDefault"])
    if not enabled:
        return False

    locale = option("LOCALE", DEFAULTS["localeDefault"])
    zone = option("TIMEZONE", DEFAULTS["zoneDefault"])
    if not re.fullmatch(r"[a-zA-Z0-9_@.\-]+", locale):
        raise ValueError(f"invalid locale {locale!r}")
    zone_dir = Path(DEFAULTS["zoneDir"])
    zone_file = zone_dir / zone
    if (
        not re.fullmatch(r"[a-zA-Z0-9_+\-]+(/[a-zA-Z0-9_+\-]+)*", zone)
        or not zone_file.is_file()
    ):
        raise ValueError(f"unknown time zone {zone!r}")
    with zone_file.open("rb") as stream:
        if stream.read(4) != b"TZif":
            raise ValueError(f"invalid zoneinfo file for {zone!r}")

    base = re.split(r"[.@]", locale, maxsplit=1)[0]
    languages = base + ":" + base.split("_")[0] if "_" in base else base
    language = option("LANGUAGE", DEFAULTS["languageDefault"] or languages)
    if not re.fullmatch(r"[a-zA-Z0-9_@.:\-]+", language):
        raise ValueError("invalid LANGUAGE list")
    for key in list(os.environ):
        if key.startswith("LC_") or key == "LOCPATH":
            del os.environ[key]
    os.environ.update(
        LANG=locale,
        LC_ALL=locale,
        LANGUAGE=language,
        TZ=zone,
        TZDIR=str(zone_dir),
        LOCALE_ARCHIVE=DEFAULTS["localeArchive"],
        # Nix glibc checks this versioned name before LOCALE_ARCHIVE.
        LOCALE_ARCHIVE_2_27=DEFAULTS["localeArchive"],
    )
    # glibc's locale command can warn and still exit successfully.
    result = subprocess.run(
        [DEFAULTS["localeBin"], "charmap"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    if result.returncode or result.stderr:
        raise ValueError(f"locale {locale!r} unavailable in packaged glibc archive")
    return files


def execute(command, argv0=None):
    # Restore the signal defaults Python changes on startup before exec.
    for sig in (signal.SIGPIPE, signal.SIGXFSZ):
        signal.signal(sig, signal.SIG_DFL)
    os.execv(command[0], [argv0 or command[0], *command[1:]])


def launch(args: list[str]):
    """Resolve user options on the host before entering the network namespace."""
    strict = switch("STRICT", DEFAULTS["strictDefault"])
    http = switch("HTTP_ENV", DEFAULTS["httpDefault"])
    check_country = switch("CHECK_COUNTRY", DEFAULTS["checkCountryDefault"])
    files = configure_region()
    prefix = []
    if strict:
        upstream = option("SOCKS_PROXY", DEFAULTS["socksDefault"])
        if not re.fullmatch(r"socks5://.+", upstream):
            raise ValueError("strict mode requires a socks5:// upstream")
        tun = Path("/dev/net/tun")
        if not tun.is_char_device() or not os.access(tun, os.R_OK | os.W_OK):
            raise RuntimeError(
                "strict mode requires a readable and writable /dev/net/tun"
            )
        prefix = [DEFAULTS["nsproxyBin"], "-x", upstream, "--"]

    proxy = port = None
    if http and strict:
        text = option("HTTP_LISTEN_PORT", DEFAULTS["listenDefault"])
        if not re.fullmatch(r"[1-9][0-9]{0,4}", text) or int(text) > 65535:
            raise ValueError(f"invalid HTTP listen port {text!r}")
        port = int(text)
        proxy = f"http://127.0.0.1:{port}"
    elif http:
        proxy = option("HTTP_PROXY", DEFAULTS["httpProxyDefault"])
        if not re.fullmatch(r"https?://.+", proxy):
            raise ValueError("expected an HTTP(S) proxy URL")

    if strict or http:
        for key in PROXY_VARS:
            os.environ.pop(key, None)
            os.environ.pop(key.upper(), None)
    os.environ.update(
        DISABLE_AUTOUPDATER="1",
        DISABLE_INSTALLATION_CHECKS="1",
        USE_BUILTIN_RIPGREP="0",
    )
    os.environ["PATH"] = os.pathsep.join(
        filter(None, [DEFAULTS["runtimePath"], os.getenv("PATH")])
    )
    proxy_log = os.getenv("CLAUDE_NIX_PROXY_LOG") if port is not None else None
    for key in list(os.environ):
        if key.startswith("CLAUDE_NIX_"):
            del os.environ[key]
    state = json.dumps(
        asdict(Session(strict, files, proxy, port, check_country, proxy_log))
    )
    execute(
        [
            *prefix,
            DEFAULTS["setprivBin"],
            "--inh-caps=-all",
            "--ambient-caps=-all",
            "--",
            LIBEXEC / "claude-session",
            state,
            *args,
        ]
    )


def bind_data(view, path, data):
    """bwrap takes ownership of these inherited FDs during exec."""
    fd = os.memfd_create("claude-" + path.name)
    with os.fdopen(fd, "wb", closefd=False) as stream:
        stream.write(data)
    os.lseek(fd, 0, os.SEEK_SET)
    os.set_inheritable(fd, True)
    view.extend(["--ro-bind-data", str(fd), path])


def etc_roots():
    """NixOS profile aliases can share an etc tree or point to distinct generations."""
    roots = [Path("/etc")]
    if Path("/etc/NIXOS").is_file():
        for alias in (
            "/etc/static",
            "/run/current-system/etc",
            "/run/booted-system/etc",
            "/nix/var/nix/profiles/system/etc",
        ):
            tree = Path(alias).resolve()
            if tree.is_dir() and tree not in roots:
                roots.append(tree)
    return roots


def mirror_etc(view, root, strict, subdir=Path(".")):
    directory = root / subdir
    view.extend(["--perms", "0755", "--tmpfs", directory])
    for entry in sorted(directory.iterdir()):
        relative = entry.relative_to(root).as_posix()
        if relative == "localtime":
            continue
        if strict and entry in (Path("/etc/resolv.conf"), Path("/etc/nsswitch.conf")):
            # nsproxy unlinks its private resolver files after mounting them.
            # Capture their contents while they are still visible here.
            bind_data(view, entry, entry.read_bytes())
        elif relative == "timezone":
            bind_data(view, entry, (os.environ["TZ"] + "\n").encode())
        elif relative in ("locale.conf", "default/locale"):
            data = "".join(
                f"{key}={os.environ[key]}\n" for key in ("LANG", "LC_ALL", "LANGUAGE")
            )
            bind_data(view, entry, data.encode())
        elif relative == "default" and os.path.lexists(entry / "locale"):
            mirror_etc(view, root, strict, Path("default"))
        elif entry.is_symlink():
            # Preserve NixOS /etc/static links, including dangling links.
            view.extend(["--symlink", os.readlink(entry), entry])
        else:
            mount = "--bind" if root == Path("/etc") else "--ro-bind"
            view.extend([mount, entry, entry])

    localtime = directory / "localtime"
    if directory == root and (root == Path("/etc") or os.path.lexists(localtime)):
        # Replace the selector itself. Binding over its resolved TZif file
        # would also change conversions explicitly requesting the host's zone.
        zone = Path(DEFAULTS["zoneDir"]) / os.environ["TZ"]
        view.extend(["--symlink", zone, localtime])
    view.extend(["--remount-ro", directory])


def enter_view(session: Session, args: list[str]):
    """Assemble mounts from the resolver and sockets visible in this namespace."""
    view = []
    if session.system_files:
        for root in etc_roots():
            mirror_etc(view, root, session.strict)
    if session.strict:
        for socket in (
            Path("/run/nscd/socket"),
            Path("/run/systemd/resolve/io.systemd.Resolve"),
        ):
            if socket.is_socket():
                view.extend(["--ro-bind", "/dev/null", socket])
    if view:
        execute(
            [
                DEFAULTS["bwrapBin"],
                "--dev-bind",
                "/",
                "/",
                *view,
                "--chdir",
                os.getcwd(),
                "--",
                LIBEXEC / "claude-run",
                json.dumps(asdict(session)),
                *args,
            ]
        )
    run_claude(session, args)


def is_listening(endpoint):
    # A dummy HTTP connection would itself generate a proxy error.
    for row in Path("/proc/net/tcp").read_text().splitlines()[1:]:
        _, local_address, _, state, *_ = row.split()
        if local_address == endpoint and state == "0A":  # TCP_LISTEN
            return True
    return False


def start_http_proxy(port: int, path: str | None):
    config = f"""Port {port}
Listen 127.0.0.1
Allow 127.0.0.1
Timeout 600
MaxClients 100
LogLevel Error
DisableViaHeader Yes
"""
    # Keep the helper out of the TUI's terminal process group. setpriv
    # still terminates it when this PID (later Claude) exits.
    log_fd = (
        os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        if path
        else subprocess.DEVNULL
    )
    try:
        proc = subprocess.Popen(
            [
                DEFAULTS["setprivBin"],
                "--pdeathsig",
                "TERM",
                "--",
                DEFAULTS["tinyproxyBin"],
                "-d",
                "-c",
                "/dev/stdin",
            ],
            stdin=subprocess.PIPE,
            stdout=log_fd,
            stderr=log_fd,
            start_new_session=True,
        )
    finally:
        if path:
            os.close(log_fd)
    try:
        with proc.stdin:
            proc.stdin.write(config.encode())
        endpoint = f"0100007F:{port:04X}"
        deadline = time.monotonic() + 5
        while proc.poll() is None and time.monotonic() < deadline:
            if is_listening(endpoint):
                return
            time.sleep(0.05)
    except BrokenPipeError:
        pass
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    detail = f"see {path}" if path else "set CLAUDE_NIX_PROXY_LOG to a file for details"
    raise RuntimeError(f"HTTP proxy failed to start on 127.0.0.1:{port}; {detail}")


def timezone_country() -> tuple[str, str]:
    zone = os.environ.get("TZ", "/etc/localtime").removeprefix(":")
    if zone.startswith("/"):
        path = Path(zone)
        # Stop at the named location: Copenhagen can itself link to Berlin.
        while path.is_file() and "/zoneinfo/" not in str(path) and path.is_symlink():
            path = path.parent / path.readlink()
        if path.is_file():
            zone = str(path).partition("/zoneinfo/")[2] or zone
    zone = zone.removeprefix("posix/").removeprefix("right/")
    # zone.tab retains each named location's country even when multiple
    # countries share identical clock rules and the TZif files are hardlinks.
    table = Path(DEFAULTS["zoneDir"]) / "zone.tab"
    for line in table.read_text().splitlines():
        if line and not line.startswith("#"):
            country, _, name, *_ = line.split("\t")
            if name == zone:
                return zone, country
    raise ValueError(
        f"cannot determine country for TZ={zone!r}; choose a geographic name from zone.tab"
    )


def check_exit_country():
    zone, country = timezone_country()
    # Probe the API hostname so a domain-based proxy rule applies to this request.
    # -q disables .curlrc (which could change the proxy, TLS or request headers).
    result = subprocess.run(
        [
            DEFAULTS["curlBin"],
            "-q",
            "--silent",
            "--max-time",
            "8",
            "--max-filesize",
            "4096",
            "--write-out",
            "\\n%{http_code}",
            "https://api.anthropic.com/cdn-cgi/trace",
        ],
        check=False,
        capture_output=True,
    )
    body, _, status = result.stdout.rpartition(b"\n")
    if result.returncode or status != b"200":
        raise RuntimeError(
            "exit country lookup at api.anthropic.com failed "
            f"(curl {result.returncode}, HTTP {status.decode('ascii', 'replace')})"
        )
    locations = [line[4:] for line in body.splitlines() if line.startswith(b"loc=")]
    if len(locations) != 1 or not re.fullmatch(rb"[A-Z]{2}", locations[0]):
        raise RuntimeError("exit country lookup returned no unique country code")
    observed = locations[0].decode("ascii")
    if observed != country:
        raise RuntimeError(
            f"exit country {observed} does not match TZ={zone} ({country})"
        )


def run_claude(session: Session, args: list[str]):
    if session.listen_port is not None:
        start_http_proxy(session.listen_port, session.proxy_log)
    # These client settings belong to Claude and its children.
    if session.http_proxy is not None:
        for key in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"):
            os.environ[key] = session.http_proxy
        os.environ["no_proxy"] = os.environ["NO_PROXY"] = "localhost,127.0.0.1,::1"
    if session.check_country:
        check_exit_country()
    execute([LIBEXEC / "claude", *args], argv0=OUT / "bin/claude")


def main():
    # Private entry points are selected by the installed filename; every
    # argument of the public 'claude' command belongs to Claude itself.
    stage = Path(sys.argv[0])
    if stage == LIBEXEC / "claude-check-country":
        check_exit_country()
    elif stage == LIBEXEC / "claude-session":
        enter_view(Session(**json.loads(sys.argv[1])), sys.argv[2:])
    elif stage == LIBEXEC / "claude-run":
        run_claude(Session(**json.loads(sys.argv[1])), sys.argv[2:])
    else:
        launch(sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"claude: {exc}", file=sys.stderr)
        sys.exit(2 if isinstance(exc, ValueError) else 1)
