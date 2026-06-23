#!/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

CFG="/etc/jffs2/anyka_cfg.ini"
LOG="/tmp/wifi_seed.log"
WIFI_CFG_YAML="/mnt/anykacam-wifi-config.yaml"

[ -f "$CFG" ] || exit 1

trim_value()
{
	echo "$1" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^['\\\"]//;s/['\\\"]$//"
}

yaml_get_value()
{
	key="$1"
	line=`grep -i "^[[:space:]]*$key[[:space:]]*:" "$WIFI_CFG_YAML" 2>/dev/null | head -n1`
	[ -z "$line" ] && return 1
	val=`echo "$line" | sed "s/^[^:]*:[[:space:]]*//;s/[[:space:]]*#.*$//"`
	trim_value "$val"
	return 0
}

normalize_auth()
{
	auth_lc=`echo "$1" | tr '[:upper:]' '[:lower:]'`
	case "$auth_lc" in
		open|none)
			echo "open"
			;;
		wpa|wpa2|wpa-psk|wpa2-psk|psk)
			echo "wpa"
			;;
		*)
			echo "$auth_lc"
			;;
	esac
}

ini_get_value()
{
	key="$1"
	awk -F= '
		/^\[wireless\]/{w=1;next}
		/^\[/{w=0}
		w==1 && $1 ~ "^[[:space:]]*"key"[[:space:]]*$" {
			v=$2
			gsub(/^[[:space:]]*/, "", v)
			gsub(/[[:space:]]*$/, "", v)
			print v
			exit
		}
	' key="$key" "$CFG"
}

set_field()
{
	key="$1"
	value="$2"
	sed -i "/^\[wireless\]/,/^\[/{s|^$key[[:blank:]]*=.*|$key\t\t\t= $value|}" "$CFG"
}

if ! grep -q "[[:space:]]/mnt[[:space:]]" /proc/mounts 2>/dev/null
then
	echo "wifi seed: /mnt not mounted, skip" >> "$LOG"
	exit 0
fi

if [ ! -f "$WIFI_CFG_YAML" ]
then
	echo "wifi seed: $WIFI_CFG_YAML not found, skip" >> "$LOG"
	exit 0
fi

SSID_NEW=`yaml_get_value "ssid"`
AUTH_NEW=`yaml_get_value "authentication"`
[ -z "$AUTH_NEW" ] && AUTH_NEW=`yaml_get_value "auth_type"`
[ -z "$AUTH_NEW" ] && AUTH_NEW=`yaml_get_value "auth"`
[ -z "$AUTH_NEW" ] && AUTH_NEW=`yaml_get_value "security"`
PASSWORD_NEW=`yaml_get_value "password"`
[ -z "$PASSWORD_NEW" ] && PASSWORD_NEW=`yaml_get_value "passphrase"`
[ -z "$PASSWORD_NEW" ] && PASSWORD_NEW=`yaml_get_value "psk"`

if [ -z "$SSID_NEW" ] || [ -z "$AUTH_NEW" ]
then
	echo "wifi seed: invalid $WIFI_CFG_YAML (missing ssid/auth), skip" >> "$LOG"
	exit 0
fi

SECURITY_NEW=`normalize_auth "$AUTH_NEW"`
MODE_NEW="Infra"
RUNNING_NEW="sta"
if [ "$SECURITY_NEW" = "open" ]
then
	PASSWORD_NEW=""
fi

CHANGED=0

SSID_CUR=`ini_get_value "ssid"`
MODE_CUR=`ini_get_value "mode"`
SECURITY_CUR=`ini_get_value "security"`
PASSWORD_CUR=`ini_get_value "password"`
RUNNING_CUR=`ini_get_value "running"`

if [ "$SSID_CUR" != "$SSID_NEW" ]
then
	echo "wifi seed: ssid [$SSID_CUR] -> [$SSID_NEW]" >> "$LOG"
	set_field "ssid" "$SSID_NEW"
	CHANGED=1
fi
if [ "$MODE_CUR" != "$MODE_NEW" ]
then
	echo "wifi seed: mode [$MODE_CUR] -> [$MODE_NEW]" >> "$LOG"
	set_field "mode" "$MODE_NEW"
	CHANGED=1
fi
if [ "$SECURITY_CUR" != "$SECURITY_NEW" ]
then
	echo "wifi seed: security [$SECURITY_CUR] -> [$SECURITY_NEW]" >> "$LOG"
	set_field "security" "$SECURITY_NEW"
	CHANGED=1
fi
if [ "$PASSWORD_CUR" != "$PASSWORD_NEW" ]
then
	echo "wifi seed: password changed" >> "$LOG"
	set_field "password" "$PASSWORD_NEW"
	CHANGED=1
fi
if [ "$RUNNING_CUR" != "$RUNNING_NEW" ]
then
	echo "wifi seed: running [$RUNNING_CUR] -> [$RUNNING_NEW]" >> "$LOG"
	set_field "running" "$RUNNING_NEW"
	CHANGED=1
fi

if [ "$CHANGED" -eq 1 ]
then
	echo "wifi seed: applied changes, rebooting" >> "$LOG"
	sync
	reboot
	exit 0
fi

echo "wifi seed: no changes needed" >> "$LOG"

sync
exit 0
