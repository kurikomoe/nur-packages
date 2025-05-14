import sys
import time
import threading
import subprocess

from network_util import execute_cmd, Command, JAVA_SERVER_PORT
from i18n import I18N
from log_utils import get_logger

logger = get_logger("indicator_menus")

SEPARATOR = "separator"


def to_bytes(data):
    if sys.version_info < (3, 0):
        data = bytes(data)
    else:
        data = bytes(data, 'utf8')
    return data


class ExitError(Exception):
    def __init__(self, message):
        super(ExitError, self).__init__(message)


def exit_client():
    if not execute_cmd(Command.ExitClient):
        raise ExitError("Can not tell java client to exit")
    logger.info("exit")


def _shell_exec(cmd):
    p = subprocess.run(['/bin/sh', '-c', cmd], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.stdout.decode('utf-8')
    return p.returncode, out.strip()


def is_java_client_running():
    code, out = _shell_exec('pgrep -x nutstore')
    if code == 0:
        return True
    if code == 1:
        return False
    raise RuntimeError('unexpected pgrep result: code={} out={}'.format(code, out))


def open_window():
    while True:
        if is_java_client_running():
            break
        time.sleep(0.5)  # wait java to start tcp server
    execute_cmd('open_main_window')


def open_window_async():
    t1 = threading.Thread(target=open_window)
    t1.setDaemon(True)
    t1.start()


def get_menus():
    return [
        (I18N.get("Open Main Panel"), lambda w, d: execute_cmd(Command.OpenMainWindow)),
        (I18N.get("Open Website"), lambda w, d: execute_cmd(Command.OpenWebsite)),
        (I18N.get("Pause Sync"), lambda w, d: execute_cmd(Command.PauseSync)),
        (SEPARATOR, None),
        (I18N.get("Invite Friends To Sync"), lambda w, d: execute_cmd(Command.InviteFriends)),
        (I18N.get("Preferences"), lambda w, d: execute_cmd(Command.OpenPreference)),
        (I18N.get("Switch Account"), lambda w, d: execute_cmd(Command.SwitchAccount)),
        (I18N.get("User Guide"), lambda w, d: execute_cmd(Command.UserGuide)),
        (SEPARATOR, None),
        (I18N.get("Pack logs"), lambda w, d: execute_cmd(Command.PackLog))
    ]
