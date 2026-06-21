#!/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
CFG_XML="/etc/jffs2/config.xml"

get_current_ip()
{
	ip=`ifconfig wlan0 2>/dev/null | awk '/inet addr:/{print $2}' | awk -F: '{print $2}'`
	if [ -z "$ip" ]
	then
		ip=`ifconfig eth0 2>/dev/null | awk '/inet addr:/{print $2}' | awk -F: '{print $2}'`
	fi
	echo "$ip"
}

update_onvif_stream_uri()
{
	ip="$1"
	[ -z "$ip" ] && return 1
	[ ! -f "$CFG_XML" ] && return 1

	tmp="/tmp/config.xml.$$"
	awk -v ip="$ip" '
	BEGIN { n=0 }
	{
		if ($0 ~ /<stream_uri>rtsp:\/\//) {
			n++
			if (n == 1) {
				$0 = "                <stream_uri>rtsp://" ip ":8554/ch0_0.264</stream_uri>"
			} else if (n == 2) {
				$0 = "                <stream_uri>rtsp://" ip ":8554/ch0_1.264</stream_uri>"
			}
		}
		print $0
	}' "$CFG_XML" > "$tmp" && mv "$tmp" "$CFG_XML"
}

wait_and_patch_ip()
{
	i=0
	while [ $i -lt 20 ]
	do
		ip=`get_current_ip`
		if [ -n "$ip" ]
		then
			update_onvif_stream_uri "$ip"
			return 0
		fi
		sleep 1
		i=`expr $i + 1`
	done
	return 1
}

wait_and_patch_ip

inifile="/etc/jffs2/anyka_cfg.ini"
onvif=`awk 'BEGIN {FS="="}/\[cloud\]/{a=1} a==1&&$1~/onvif/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`
if [ "$onvif" = "1" ]
then
	pid=`pgrep cmd`
	if [ "$pid" = "" ]
	then
		cmd &
	fi
	pid=`pgrep discovery`
	if [ "$pid" = "" ]
	then
		discovery &
	fi
fi

pid=`pgrep anyka_ipc`
if [ "$pid" = "" ]
then
	anyka_ipc &
fi

exit 0
