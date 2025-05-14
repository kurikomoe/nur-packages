import sys
import socket
from log_utils import get_logger

JAVA_SERVER_PORT = 19080

logger = get_logger("network_util")

class Command:
    OpenMainWindow = "open_main_window"
    OpenWebsite = "open_website"
    InviteFriends = "open_invite_friends"
    PauseSync = "pause_sync"
    OpenPreference = "open_preference"
    SwitchAccount = "switch_account"
    UserGuide = "user_guide"
    PackLog = "pack_log"
    ExitClient = "exit_client"
    QueryIsPaused = "is_paused"
    OpenFileInLightApp = "open_file_in_lightapp"
    OpenWizardInLightApp = "open_wizard_in_lightapp"


def to_bytes(data):
    if sys.version_info < (3, 0):
        data = bytes(data)
    else:
        data = bytes(data, 'utf8')
    return data


# return socket send result
def execute_cmd(cmd):
    logger.debug("[TRAY_CMD] " + cmd)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(('localhost', JAVA_SERVER_PORT))
        sock.send(to_bytes(cmd + '\ndone\n'))
        return True
    except socket.error:
        logger.exception("execute cmd [%s] error" % cmd)
    finally:
        sock.close()
    return False

