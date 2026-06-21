#!/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

CFG="/etc/jffs2/anyka_cfg.ini"
LOG="/tmp/wifi_seed.log"

# Set these values before use; do not commit real credentials
SSID="<YOUR_WIFI_SSID>"
MODE="Infra"
SECURITY="wpa"
PASSWORD="<YOUR_WIFI_PASSWORD>"
RUNNING="sta"

[ -f "$CFG" ] || exit 1

echo "wifi seed: forcing wireless section values" >> "$LOG"

sed -i "/^\[wireless\]/,/^\[/{s|^ssid[[:blank:]]*=.*|ssid\t\t\t= $SSID|}" "$CFG"
sed -i "/^\[wireless\]/,/^\[/{s|^mode[[:blank:]]*=.*|mode\t\t\t= $MODE|}" "$CFG"
sed -i "/^\[wireless\]/,/^\[/{s|^security[[:blank:]]*=.*|security\t\t\t= $SECURITY|}" "$CFG"
sed -i "/^\[wireless\]/,/^\[/{s|^password[[:blank:]]*=.*|password\t\t\t= $PASSWORD|}" "$CFG"
sed -i "/^\[wireless\]/,/^\[/{s|^running[[:blank:]]*=.*|running\t\t\t= $RUNNING|}" "$CFG"

sync
exit 0
