# 04 — Firmware Customizations (Persistent)

To unlock RTSP/ONVIF services and configure the camera to boot without cloud dependency, you need to apply startup customization hooks. These scripts are pre-provided in the `scripts/` directory of this repository and should be copied into the unpacked SquashFS filesystem root (`usr_sqsh4_root`).

At runtime, the mount structure places these files under `/usr/sbin/`.

---

## A) Startup Hooks Integration

We patch the camera's default startup wrapper, `/sbin/anyka_ipc.sh` (which runs as `/usr/sbin/anyka_ipc.sh` at boot), to check for and execute custom scripts before starting the main daemon.

### Patch in `sbin/anyka_ipc.sh`
The custom wrapper (`scripts/sbin_anyka_ipc.sh`) includes these hook definitions at the top:
```sh
START_HOOK="/usr/sbin/start_ipc_hook.sh"
RESTART_HOOK="/usr/sbin/restart_ipc_hook.sh"

run_hook()
{
	hook="$1"
	if [ -x "$hook" ]
	then
		echo "run hook: $hook"
		"$hook"
		return $?
	fi
	return 127
}
```

Then in `start()` and `restart()`, the hook is executed first. If the hook exits successfully (`0`), the default startup flow is bypassed:

```sh
start ()
{
	echo "start ipc service......"
	run_hook "$START_HOOK"
	if [ $? -eq 0 ]
	then
		echo "start hook finished"
		return
	fi
    ...
```

---

## B) Hook Scripts

### 1. The Startup Hook (`sbin/start_ipc_hook.sh`)
This hook is critical. It performs two main functions:
1. **Dynamic IP Patching**: It waits for the camera to connect to the network and obtain an IP address (`wlan0` or `eth0`). Once obtained, it rewrites `/etc/jffs2/config.xml` to update the ONVIF stream URIs with the camera's correct local IP address.
2. **Clean Daemon Bring-up**: It starts `anyka_ipc` in the background, and additionally checks if ONVIF is enabled in `anyka_cfg.ini`. If enabled, it also starts the standard ONVIF daemons (`cmd` and `discovery`) so ONVIF discovery functions normally.

Here is the complete startup hook logic (`scripts/sbin_start_ipc_hook.sh`):
```sh
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
```

### 2. The Restart Hook (`sbin/restart_ipc_hook.sh`)
This script kills the main camera daemon gracefully and invokes the startup hook to reinitialize the video streams and local endpoints:
```sh
#!/bin/sh
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

killall -15 anyka_ipc
sleep 1
/usr/sbin/start_ipc_hook.sh

exit 0
```

---

## C) Wi-Fi Seeding Configuration (Provisioning)

If you are deploying a new camera or recovering one, you can seed wireless credentials directly into the config directory `/etc/jffs2/anyka_cfg.ini`. 

The helper script `scripts/sbin_seed_wifi_cfg.sh` sets the `[wireless]` section parameters:
- `ssid = <YOUR_WIFI_SSID>`
- `mode = Infra`
- `security = wpa`
- `password = <YOUR_WIFI_PASSWORD>`
- `running = sta`

> [!WARNING]
> Do not commit real SSID or Wi-Fi passwords to a public Git repository. Keep credentials in a local, uncommitted copy of the script.

### Call Chain Integration
The custom init script `scripts/sbin_service.sh` (copied to `/sbin/service.sh` in SquashFS) executes this seeding script right before starting the camera wrapper:
```sh
	/usr/sbin/seed_wifi_cfg.sh || true
	/usr/sbin/anyka_ipc.sh start
```

---

« [Chapter 03: Binary Patching](03-anyka_ipc-binary-patch.md) | [Table of Contents](../README.md) | [Chapter 05: Build and Repack](05-build-and-pack.md) »
