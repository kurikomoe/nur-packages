#!/usr/bin/env sh

BASE_DIR=$(dirname $0)/..

AUTOSTART_DIR=~/.config/autostart
MENU_DIR=~/.local/share/applications
ICON_DIR=~/.local/share/icons/hicolor/512x512/apps

set -e

mkdir -p $AUTOSTART_DIR
cp $BASE_DIR/gnome-config/autostart/*.desktop $AUTOSTART_DIR

mkdir -p $MENU_DIR
cp  $BASE_DIR/gnome-config/menu/*.desktop $MENU_DIR

mkdir -p $ICON_DIR
cp $BASE_DIR/app-icon/nutstore.png $ICON_DIR

# we need to update icon cache
gtk-update-icon-cache --ignore-theme-index $ICON_DIR/../.. > /dev/null 2>&1

echo "Install Nutstore done."
echo "Now you can start Nutstore from menu: Applications > Internet > Nutstore"
