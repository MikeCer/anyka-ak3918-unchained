# 06 — Flash and Validate

## Flash via SD update path

Place on SD root:

- `usr.sqsh4` (rename patched image to this exact name)
- `usr.sqsh4.md5` (recommended)

Trigger the update using the camera's update sequence. On the reference camera, this is done by clicking and holding the **reset button**  until the camera plays buzzer sound two times and then relase the button. The camera speaker will plays a voice prompt (e.g., "Updating" or a similar sound). This triggers `/usr/sbin/update.sh`, which automatically maps the `usr.sqsh4` file from the SD card to MTD2 (`/usr` partition).

> [!IMPORTANT]
> **Do NOT unplug the camera during the update!** The flashing process typically takes 3-4 minutes. During the writing phase, an internal green LED will blink. Once the update is complete and the script auto-reboots the device, the LED will turn red.

## Post-boot validation

From shell:

```sh
md5sum /usr/bin/anyka_ipc
ps | grep anyka_ipc | grep -v grep
```

Check hooks and wrappers:

```sh
ls -l /usr/sbin/anyka_ipc.sh /usr/sbin/start_ipc_hook.sh /usr/sbin/restart_ipc_hook.sh /usr/sbin/seed_wifi_cfg.sh
```

Check network services:

```sh
netstat -anp 2>/dev/null | grep -E ':(8554|8000) '
```

Expected RTSP paths:

- `rtsp://<camera_ip>:8554/ch0_0.264`
- `rtsp://<camera_ip>:8554/ch0_1.264`

---

« [Chapter 05: Build and Repack](05-build-and-pack.md) | [Table of Contents](../README.md) | [Chapter 07: Troubleshooting](07-troubleshooting.md) »

