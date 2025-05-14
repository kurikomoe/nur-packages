#!/usr/bin/env python3
from log_utils import get_logger
logger = get_logger("indicator")

import os
from i18n import I18N
from indicator_menus import exit_client, get_menus, SEPARATOR, ExitError
from resource_manage import PicturesManage

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GObject


def gi_import(name, ver):
    try:
        gi.require_version(name, ver)
        return True, None
    except Exception as e:
        return False, e


def gi_import_app_indicator():
    ok, e1 = gi_import('AppIndicator3', '0.1')
    if not ok:
        ok, e2 = gi_import('AyatanaAppIndicator3', '0.1')
        if not ok:
            raise Exception('cannot import app indicator: %s; %s' % (e1, e2))
        else:
            return 1
    else:
        return 0


if gi_import_app_indicator() == 0:
    from gi.repository import AppIndicator3 as appindicator
else:
    from gi.repository import AyatanaAppIndicator3 as appindicator


class NutstoreIndicator(Gtk.Application):
    def __init__(self, app_name):
        self.is_app_crash = False
        self.indicator = appindicator.Indicator.new(
            app_name,
            PicturesManage.get_logo(),
            appindicator.IndicatorCategory.APPLICATION_STATUS)
        self.indicator.set_status(appindicator.IndicatorStatus.ACTIVE)
        self.menu = Gtk.Menu()
        self.PauseMenuItem = None
        self.sync_status = None
        self.build_menus()

    def build_menus(self):
        item = Gtk.MenuItem()
        item.set_label(I18N.get("Exit"))
        item.connect("activate", self.exit_client, '')
        self.menu.append(item)
        for i in get_menus():
            menu_name, func = i
            if menu_name == SEPARATOR:
                item = Gtk.SeparatorMenuItem()
                self.menu.append(item)
                continue

            item = Gtk.MenuItem()
            item.set_label(menu_name)
            item.connect("activate", func, '')
            self.menu.append(item)
            # save paused menu-item for later update
            if menu_name == I18N.get("Pause Sync"):
                self.PauseMenuItem = item
        self.menu.show_all()
        self.indicator.set_menu(self.menu)

    def run(self):
        Gtk.main()

    def quit(self):
        self.exit_client(None, None)

    def exit_client(self, w, data):
        try:
            exit_client()
        except ExitError:
            # force quit java client if communication failed
            logger.exception("force close nutstore")
            os.system("pkill nutstore")
            Gtk.main_quit()

    def update_paused_menu(self, is_paused):
        status_text = I18N.get("Resume Sync" if is_paused else "Pause Sync")
        self.PauseMenuItem.set_label(status_text)

    def update_sync_status(self, status):
        self.indicator.set_icon(PicturesManage.get_status_pic(status))
        if status == PicturesManage.OOPS:
            self.is_app_crash = True
            self.update_menus_on_crash()
            logger.warn("app crashed delete others tray-menus")
        else:
            # restore menus
            if self.is_app_crash:
                self.is_app_crash = False
                self.build_menus()
            self.update_paused_menu(status == PicturesManage.PAUSED)

    def set_no_state(self):
        GObject.idle_add(self.update_sync_status, PicturesManage.NORMAL)

    # NS-5383 when app crashed disable all tray menu items except 'exit' and 'pack logs'
    def update_menus_on_crash(self):
        kept_labels = [I18N.get("Exit"), I18N.get("Pack logs")]
        for menuItem in self.menu:
            if menuItem.get_label() not in kept_labels:
                self.menu.remove(menuItem)

    def update_status(self, status):
        GObject.idle_add(self.update_sync_status, status)


if __name__ == '__main__':
    GObject.threads_init()
    APP = NutstoreIndicator('Nutstore')
    APP.run()
