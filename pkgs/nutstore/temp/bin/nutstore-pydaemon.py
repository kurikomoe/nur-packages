#!/usr/bin/env python3
# vim: set sw=4 ts=4:

from __future__ import print_function
import socket
import os
import threading
import time
import sys
import platform
import tempfile
import fcntl
import errno
import base64
import subprocess
import signal
from i18n import I18N
from indicator_menus import is_java_client_running, open_window
from resource_manage import PicturesManage
from log_utils import get_logger
from network_util import execute_cmd, Command


def get_dist_dir():
    """Get the nutstore distribution install directory by the path to the python script"""
    path = os.path.dirname(sys.argv[0])
    abs_path = os.path.abspath(path)
    if os.path.basename(abs_path) != 'bin':
        raise SystemError("the python script is not under bin")
    return os.path.dirname(abs_path)


def get_nutstore_dir():
    return os.path.dirname(get_dist_dir())


logger = get_logger("daemon")

APP_NAME = "Nutstore"
LOCAL_PORT = 19645
CAN_SELECT_FILE = False
USE_PYTHON_TRAY = False
APP_INDICATOR = None
IS_UBUNTU_18 = False
IS_TRAY_DEPENDS_INSTALLED = False
USE_GTK_NOTIFY = False

try:
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('Notify', '0.7')
    from gi.repository import GObject, Gtk, Notify
    logger.debug("Notify.init")
    Notify.init(APP_NAME)
    USE_GTK_NOTIFY = True
except ImportError:
    logger.info("can't import gi")
else:
    try:
        from nutstore_indicator import NutstoreIndicator
    except Exception as e:
        logger.info("can't import appindicator: %s" % e)
    else:
        IS_TRAY_DEPENDS_INSTALLED = True

try:
    # [NS-9036] Fix `nautilus --version' SIGSEGV in Ubuntu 20.04 LTS
    CAN_SELECT_FILE = (subprocess.call(['which', 'nautilus'], stdout=subprocess.DEVNULL) == 0)
except Exception as e:
    logger.exception("Cannot found expected file manager")


def parse_os_release():
    d = {}
    path = '/etc/os-release'

    if not os.path.exists(path):
        return d

    with open(path) as f:
        lines = [l.strip() for l in f]
        for line in lines:
            # Lines beginning with "#" shall be ignored as comments.
            # Blank lines are permitted and ignored.
            if len(line) == 0 or line[0] == '#':
                continue
            i = line.find('=')
            if i <= 0 or i == len(line) - 1:
                continue
            lhs = line[:i]
            rhs = line[i + 1:].strip('"')
            d[lhs] = rhs

    return d


#
# see:
# https://stackoverflow.com/questions/47838800/etc-lsb-release-vs-etc-os-release
# https://www.freedesktop.org/software/systemd/man/os-release.html
#
def is_ubuntu_18_or_later():
    d = parse_os_release()
    return 'ID' in d and 'VERSION_ID' in d and      \
           d['ID'] == 'ubuntu' and int(float(d['VERSION_ID'])) >= 18


def is_linux():
    return platform.system() == 'Linux'


def is_OSX():
    return platform.system() == 'Darwin'


def set_dir_icon(dir_path, icon_type):
    """set the custom icon of the directory """
    if not is_linux(): return

    dist_dir = get_dist_dir()
    resource_dir = os.path.join(dist_dir, 'res')

    if icon_type == 'normal':
        os.system('gio set -t unset "%s" metadata::custom-icon' % dir_path)
    elif icon_type == 'sandbox_ronly_bound':
        os.system('gio set -t string "%s" metadata::custom-icon file://%s' % (
            dir_path, os.path.join(resource_dir, 'linux_sandbox_ronly_bound.png')))
    elif icon_type == 'sandbox_rw_bound':
        os.system('gio set -t string "%s" metadata::custom-icon file://%s' % (
            dir_path, os.path.join(resource_dir, 'linux_sandbox_rw_bound.png')))
    else:
        logger.warning('Unknown directory type %s' % icon_type)


def notifier_open_callback(notif, action, url):
    os.system('xdg-open "%s"' % url)


def notifier_closed(notif):
    notif.close()


def show_message(opts):
    if USE_GTK_NOTIFY:
        GObject.idle_add(gtk_notify, opts)


def gtk_notify(opts):
    title = opts['TITLE']
    desc = opts['DESC'] if 'DESC' in opts else ''
    level = opts['LEVEL'] if 'LEVEL' in opts else 'normal'
    timeout = int(opts['TIMEOUT']) if 'TIMEOUT' in opts else 10
    url = opts['URL'] if 'URL' in opts else None

    notify = Notify.Notification.new(
        title, desc, PicturesManage.get_logo()
    )

    if level == 'critical':
        notify.set_urgency(Notify.Urgency.CRITICAL)
    elif level == 'low':
        notify.set_urgency(Notify.Urgency.LOW)
    else:
        notify.set_urgency(Notify.Urgency.NORMAL)

    if timeout > 0:
        notify.set_timeout(timeout * 1000)
    else:
        notify.set_timeout(Notify.EXPIRES_NEVER)

    # ubuntu 16.04 will show a dialog if url is set
    if IS_UBUNTU_18 and url:
        notify.add_action("Open", I18N.get("Open"), notifier_open_callback, url)
        notify.connect('closed', lambda n: n.close())
    notify.show()
    # must call Gtk.main() to apply notification action
    if url:
        Gtk.main()
        Gtk.main_quit()


show_message.message_counter = 0


class JavaAppWatchDog(threading.Thread):
    def __init__(self):
        # invoke the super class's constructor, if it has
        fun = getattr(threading.Thread, "__init__", lambda x: None)
        fun(self)
        self.daemon = True
        # It should only be set when the java app is restarted to migrate to another nutstore home
        self.__new_nutstore_home = None
        # It should only be set when the java app is restarted by adding more ignore path
        self.__ignore_path_list = None
        # How many times the java app has been restarted
        self.__restart_num = 0
        # It should only be set when the java app is restarted by switch account
        self.__switch_account = None
        # flag to indicate whether the watch dog thread should quit
        self.__exit = False
        # debug settings
        self.__cli_args = ' '.join(sys.argv[1:])
        self.__lock = threading.RLock()

    def set_new_nutstore_home(self, new_home_dir):
        self.__lock.acquire()
        try:
            self.__new_nutstore_home = new_home_dir
        finally:
            self.__lock.release()

    def get_new_nutstore_home(self):
        self.__lock.acquire()
        try:
            return self.__new_nutstore_home
        finally:
            self.__lock.release()

    # Used to tell the java app to migrate to a new nutstore home dir
    new_nutstore_home = property(get_new_nutstore_home, set_new_nutstore_home)

    def set_ignore_path_list(self, ignore_path_list):
        self.__lock.acquire()
        try:
            self.__ignore_path_list = ignore_path_list
        finally:
            self.__lock.release()

    def get_ignore_path_list(self):
        self.__lock.acquire()
        try:
            return self.__ignore_path_list
        finally:
            self.__lock.release()

    # Used to tell the java app to change the ignore path list
    ignore_path_list = property(get_ignore_path_list, set_ignore_path_list)

    def set_switch_account(self, arg):
        self.__lock.acquire()
        try:
            self.__switch_account = arg
        finally:
            self.__lock.release()

    def get_switch_account(self):
        self.__lock.acquire()
        try:
            return self.__switch_account
        finally:
            self.__lock.release()

    # Used to tell the java app to switch account
    switch_account = property(get_switch_account, set_switch_account)

    def get_class_path(self, lib_dir):
        class_path = []
        for name in os.listdir(lib_dir):
            child = os.path.join(lib_dir, name)
            if os.path.isdir(child) and child != 'native':
                class_path.extend(self.get_class_path(child))
            elif os.path.isfile(child) and name.endswith('.jar'):
                class_path.append(child)
        return class_path

    # see:
    #   https://bugs.eclipse.org/bugs/show_bug.cgi?id=577515
    #   https://workspace.jianguoyun.com/task/tickets/dL8dgpPtj6DrrAD0S6kUH-G3RAAMWZJPQzFxs6Q44BQ=
    def is_wayland_windowing_system(self):
        xdg_session_type = os.getenv('XDG_SESSION_TYPE')
        return xdg_session_type is not None and xdg_session_type.lower() == 'wayland'

    def start_java_app(self, args):
        """ start the java client application. The directory hierarchy is hard coded. This method is blocked until
            the java application is terminated.
           args -- the string passed as application string
        """
        const_jvm_settings = '-ea -client -Dfile.encoding=UTF-8 -Xmx2048M -XX:MinHeapFreeRatio=20 ' \
                             '-XX:MaxHeapFreeRatio=40 -Dlog4j.defaultInitOverride=true'
        const_jvm_settings += ' -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=%s/.nutstore/logs/javabe.hprof' % os.path.expanduser('~')
        if is_OSX():
            const_jvm_settings += ' -XstartOnFirstThread'

        # String template in Java21 is a preview feature, '--enable-preview' flag is needed to run the jar.
        const_jvm_settings += ' --enable-preview'

        dist_dir = get_dist_dir()

        java_path = os.path.join(dist_dir, "jre/bin/nutstore")
        conf_dir = os.path.join(dist_dir, 'conf')
        lib_dir = os.path.join(dist_dir, 'lib')
        native_lib_dir = os.path.join(lib_dir, 'native')

        # scale factor is set to the native zoom (with 1% as minimal step).
        # https://www.eclipse.org/eclipse/news/4.6/platform.php#swt-autoscale-tweaks
        jvm_settings_A = '-Dswt.autoScale=exact -Djava.util.logging.config.file=%s/java.logging.properties ' \
                         '-Dnutstore.config.dir=%s -Dnutstore.resource.dir=%s' % (
                             conf_dir, conf_dir, dist_dir)

        jvm_settings_B = '-Djava.library.path=%s -cp %s nutstore.client.gui.NutstoreGUI %s' % (
            native_lib_dir, ':'.join(self.get_class_path(lib_dir)), args)

        jvm_settings = '%s %s %s %s' % (java_path, const_jvm_settings, jvm_settings_A, jvm_settings_B)
        if USE_PYTHON_TRAY:
            jvm_settings += " --use-python-tray"

        if self.is_wayland_windowing_system():
            logger.info('Detected Wayland windowing system, switch GDK backend to X11')
            jvm_settings = 'GDK_BACKEND=x11 ' + jvm_settings

        # [WS-252514] Disable WebKit Accelerated Compositing mode to fix webui bugs
        jvm_settings = 'WEBKIT_DISABLE_COMPOSITING_MODE=1 ' + jvm_settings

        os.system(jvm_settings)

    def is_java_app_alive(self, block=True):
        """ check whether the java client is still alive by try to lock the exclusive lock 
            block -- block to acquire the file lock if it is set as True """
        lock_file_path = os.path.join(os.path.expanduser('~'), '.nutstore', '.nutstore.flock')
        if not os.path.isfile(lock_file_path):
            return False

        lock_file = None
        # Python 2.4 doesn't support try-except-finally, but support try-except and try-finally
        try:
            try:
                lock_file = open(lock_file_path, 'w')
                lock_flag = fcntl.LOCK_EX
                if not block: lock_flag |= fcntl.LOCK_NB
                fcntl.lockf(lock_file, lock_flag)
                # we can acquire the lock, so the java client must be dead
                fcntl.lockf(lock_file, fcntl.LOCK_UN)
                return False
            except IOError as exception:
                if exception.errno == errno.EAGAIN or exception.errno == errno.EACCES:
                    # can not acquire the file lock,  the java client is alive
                    return True
                raise
        finally:
            if lock_file:
                lock_file.close()

    def exit(self):
        """ Tell the watch dog thread to exit """
        self.__lock.acquire()
        try:
            self.__exit = True
        finally:
            self.__lock.release()

    def should_exit(self):
        self.__lock.acquire()
        try:
            return self.__exit
        finally:
            self.__lock.release()

    def inc_and_get_restart_num(self):
        self.__lock.acquire()
        try:
            self.__restart_num += 1
            return self.__restart_num
        finally:
            self.__lock.release()

    def reset_restart_num(self):
        self.__lock.acquire()
        try:
            self.__restart_num = 0
        finally:
            self.__lock.release()

    def run(self):
        time_start = 0
        while not self.should_exit():
            # double check should_exit() after the blocking wait on the file lock
            if not self.is_java_app_alive() and not self.should_exit():
                logger.info('The java client is dead, try to restart it')
                reset_app_status()
                now = time.time()
                if now - time_start > 600:
                    # reset the restart number every 10 minutes
                    self.reset_restart_num()
                    time_start = now
                # Tell the java client how many times it has been restarted
                restart_num = self.inc_and_get_restart_num()
                if restart_num > 10:
                    logger.warning('We have restarted %d times, so abort it' % restart_num)
                    # avoid restarting the java client again and again. The threshold should be
                    # larger than the threshold of java client, which is 5 so that java client can detect the
                    # problem and notify the user. This should only be triggered when java client is
                    # crashed too early, e.g. the gnome/gtk environment is not ready and it can not
                    # be initialized
                    os._exit(-1)

                if self.__cli_args:
                    extra_args = self.__cli_args
                    self.__cli_args = None
                else:
                    extra_args = ''

                extra_args = '%s --restart %d ' % (extra_args, restart_num)
                new_home = self.new_nutstore_home
                if new_home:
                    # clear it so that we never migrate the nutstore box again and again
                    self.new_nutstore_home = None
                    extra_args = '%s --migrate %s ' % (extra_args, new_home)

                ignore_path = self.ignore_path_list
                if ignore_path:
                    self.ignore_path_list = None
                    extra_args = '%s --ignore-path %s ' % (extra_args, ignore_path)

                switch_account_arg = self.switch_account
                if switch_account_arg:
                    self.switch_account = None
                    extra_args = '%s --switch-account %s ' % (extra_args, switch_account_arg)
                logger.debug("extra_args " + extra_args)
                self.start_java_app(extra_args)

                # Backoff before restart it again. If we restart it too frequently, something unexpected will happen.
                # For exmaple, it might prevent the GUI process from being shutdown properly.
                time.sleep(5)


class FileOrURLAnchor(threading.Thread):
    """ open a file or URL in another thread, that is, the original thread will not be blocked to wait for the script return"""

    def __init__(self, file_or_url):
        # invoke the super class's constructor, if it has
        fun = getattr(threading.Thread, "__init__", lambda x: None)
        fun(self)
        self.daemon = True
        self.__file_or_url = file_or_url
        self.__is_url = not file_or_url.startswith('/')

    def open_file_with_select(self):
        if self.__is_url:
            self.xdg_open()
            return

        if CAN_SELECT_FILE:
            try:
                subprocess.call(["nautilus", self.__file_or_url])
            except OSError as e:
                logger.exception("cannot execute nautilus")
            return

        if os.path.isfile(self.__file_or_url):
            self.__file_or_url = os.path.dirname(self.__file_or_url)
        self.xdg_open()

    def xdg_open(self):
        """open a URL or file address by xdg_open. This is only works for linux. """
        try:
            os.system('xdg-open "%s"' % self.__file_or_url)
        except OSError as exception:
            logger.exception('Cannot execute xdg-open')

    def osx_open(self):
        """open a URL or file address by open. This is only works for mac os x. """
        try:
            os.system('open "%s"' % self.__file_or_url)
        except OSError:
            logger.exception('Cannot execute open')

    def run(self):
        if is_linux():
            self.open_file_with_select()
        elif is_OSX():
            self.osx_open()
        else:
            logger.warning("unknown os type %s" % platform.system())


def upgrade(tar_file):
    """upgrade the nutstore runtime, by zipping out the tar file and execute the upgrade script """

    tmp_dir = tempfile.mkdtemp(prefix="Nutstore")
    os.system('tar xzf "%s" -C "%s"' % (tar_file, tmp_dir))
    os.execv(os.path.join(tmp_dir, "bin", "runtime_upgrade"), ("runtime_upgrade", tar_file))


def main_loop():
    watchDog = JavaAppWatchDog()
    watchDog.start()

    listen = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listen.bind(('localhost', LOCAL_PORT))

    while True:
        listen.listen(16)
        (conn, addr) = listen.accept()

        file = None
        try:
            # NS-4828 set mode='rw' cause python3 can't write without 'w'
            file = conn.makefile(mode='rw')
            lines = []
            while True:
                line = file.readline().rstrip('\r\n')
                lines.append(line)
                if line == 'done' or line == '':
                    break

            if lines[-1] != 'done':
                logger.warning('malformed request %s' % lines)
                continue

            cmd = lines[0]
            logger.debug("[CMD] " + cmd)
            payload = None
            if len(cmd) >= 2:
                payload = lines[1]
                logger.debug("[PLD] " + payload)
            if cmd == 'open':
                if len(lines) != 3:
                    logger.warning('malformed request %s' % lines)
                else:
                    # This line is encoded by base64
                    file_or_url = base64.standard_b64decode(lines[1])
                    if sys.version_info >= (3, 0):
                        file_or_url = file_or_url.decode()
                    anchor = FileOrURLAnchor(file_or_url)
                    anchor.start()
            elif cmd == 'migrate_home':
                reset_app_status()
                if len(lines) != 3:
                    logger.warning('malformed request %s' % lines)
                else:
                    watchDog.new_nutstore_home = payload
                    # send back the response only when we are prepared to migrate the home to another dir
                    file.write('rsp\ndone\n')
            elif cmd == 'ignore_paths':
                reset_app_status()
                if len(lines) != 3:
                    logger.warning('malformed request %s' % lines)
                else:
                    watchDog.ignore_path_list = payload
                    # send back the response only when we are prepared to migrate the home to another dir
                    file.write('rsp\ndone\n')
            elif cmd == 'switch_account':
                reset_app_status()
                if len(lines) != 3:
                    logger.warning('malformed request %s' % lines)
                else:
                    watchDog.switch_account = payload
                    # send back the response only when we are prepared to switch account
                    file.write('rsp\ndone\n')
            elif cmd == 'set_folder_icon':
                if len(lines) != 4:
                    logger.warning('malformed request %s ' % lines)
                else:
                    # This line is encoded by base64
                    dir_path = base64.standard_b64decode(payload).decode('utf-8') # convert bytes to str
                    icon_type = lines[2]
                    logger.debug("set_dir_icon: %s, %s" % (dir_path, icon_type))
                    set_dir_icon(dir_path, icon_type)
                    # send back the response only when we are prepared to migrate the home to another dir
                    file.write('rsp\ndone\n')
            elif cmd == 'show_message':
                if len(lines) < 3:
                    logger.warning('malformed request %s ' % lines)
                else:
                    opts = {}
                    for s in lines[1:-1]:
                        kv_array = s.split('=', 1)
                        if len(kv_array) == 2:
                            key = kv_array[0].strip(' ')
                            val = kv_array[1].strip(' ')
                            opts[key] = val
                    if not 'TITLE' in opts:
                        logger.warning('TITLE is required but not found in request: %s ' % lines)
                    else:
                        file.write('rsp\ndone\n')
                        show_message(opts)
            elif cmd == 'restart':
                # The java app likes to restart itself, reset the restart number so that it will not report the failure
                # because the java app is restarted frequently
                watchDog.reset_restart_num()
                reset_app_status()
                file.write('rsp\ndone\n')
            elif cmd == 'upgrade':
                if len(lines) != 3:
                    logger.warning('malformed request %s' % lines)
                else:
                    # avoid the watch dog to restart the java application
                    watchDog.exit()
                    # ack the java client so that it can quit immediately
                    file.write('rsp\ndone\n')
                    # close the socket because we will start to execute the script
                    file.close()
                    conn.close()
                    file = None
                    conn = None
                    listen.close()

                    # When the watch dog is dead, we are sure that the java client was exit
                    watchDog.join()

                    upgrade(payload)
            elif cmd == 'exit':
                file.write('rsp\ndone\n')
                # Avoid the watch dog to restart the Java application
                watchDog.exit()
                if USE_PYTHON_TRAY:
                    Gtk.main_quit()
                logger.info("exit")
                return
            elif USE_PYTHON_TRAY:
                status = payload
                if cmd == "update_status":
                    file.write('rsp\ndone\n')
                    APP_INDICATOR.update_status(status)
            else:
                logger.warning("unknown request %s " % lines)
        finally:
            if file: file.close()
            if conn: conn.close()


def reset_app_status():
    # global APP
    if USE_PYTHON_TRAY and APP_INDICATOR is not None:
        APP_INDICATOR.set_no_state()


def sigint_handler(sig, frame):
    logger.info("exit from SIGINT")
    sys.exit(1)


def parse_file_to_open_in_lightapp():
    if len(sys.argv) > 1:
        for i in range(1,len(sys.argv)):
            if sys.argv[i] == '--lightappFilePath':
                if i < len(sys.argv) - 1 and not sys.argv[i + 1].startswith('-'):
                    return True, sys.argv[i + 1]
                else:
                    return True, None 
    return False, None

def open_file_in_lightapp(path):
    cmd = Command.OpenFileInLightApp
    cmd += '\r\n'
    cmd += 'path\t{P}'.format(P=path)
    execute_cmd(cmd)

def open_wizard_in_lightapp():
    execute_cmd(Command.OpenWizardInLightApp)

if __name__ == '__main__':
    signal.signal(signal.SIGINT, sigint_handler)
    if is_java_client_running():
        has_file_by_lightapp, path = parse_file_to_open_in_lightapp()
        if has_file_by_lightapp:
            if path: open_file_in_lightapp(path)
            else: open_wizard_in_lightapp()
        else:
            open_window()
    else:
        # [WS-274216] The nutstore package from Arch User Repository(AUR) is installed in /opt/nutstore by default, 
        # while the Nutstore auto updater will extract the updated version to ~/.nutstore/dist, 
        # after auto update when user start the AUR package again, the app may crash due to incompatible db schame upgrade.
        # To workaround this, we should always prefer to run the nutstore-pydaemon.py script in ~/.nutstore/dist/bin/.

        # Check the current script path, if it's not in ~/.nutstore/dist/bin/, we start ~/.nutstore/bin/dist/nutstore-pydaemon.py instead and quit the current script.
        current_script = os.path.realpath(sys.argv[0])
        logger.info("current_script_path: {}".format(current_script))
        prefered_script = os.path.join(os.path.expanduser('~'), '.nutstore', 'dist', 'bin', 'nutstore-pydaemon.py')
        if os.path.exists(prefered_script) and not os.path.samefile(current_script, prefered_script):
            logger.warning("app is not installed into the home dir, and the prefered script found: {}, starting it...".format(prefered_script))
            args = ['/usr/bin/python3', prefered_script] + sys.argv[1:]
            os.execve(args[0], args, os.environ)

        # NS-4930 java based tray can't display in latest gnome environment so we reimplement it by appindicator
        if USE_GTK_NOTIFY:
            if is_ubuntu_18_or_later(): IS_UBUNTU_18 = True
            t = threading.Thread(target=main_loop)
            t.setDaemon(True)
            t.start()

            if IS_TRAY_DEPENDS_INSTALLED:
                logger.debug("start appindicator")
                USE_PYTHON_TRAY = True
                APP_INDICATOR = NutstoreIndicator(APP_NAME)
                GObject.threads_init()
                APP_INDICATOR.run()
            else:
                logger.info("appindicator depends not satisfield")
                Gtk.main()
        else:
            main_loop()
