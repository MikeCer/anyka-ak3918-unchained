# 00 — Gaining Telnet Access

This guide documents a practical workflow for unlocking a new Anyka AK3918-family camera using the same approach validated on the analyzed device. The procedure starts from the point where FTP access is available but telnet shell access is blocked by an unknown password, and the goal is to gain a root shell, inspect startup behavior, and enable local services such as RTSP and ONVIF.

## Scope and assumptions

The documented camera exposes FTP, stores its active configuration in `/etc/jffs2/anyka_cfg.ini`, contains `anyka_ipc`, `cmd`, and `discovery` components, and ships with ONVIF and RTSP libraries such as `libOnvif.so` and `librtsp.so`. The analyzed device also showed the typical Anyka startup model in which `anyka_ipc.sh` reads the config file and conditionally launches `cmd`, `discovery`, and `anyka_ipc` when ONVIF is enabled.

Use this workflow only on hardware that is owned or explicitly authorized for testing. A mistaken edit to `/etc/jffs2/shadow` or the startup scripts can lock out telnet access until the original file is restored over FTP.

## What was confirmed on the reference camera

The reference camera responded on FTP and exposed a filesystem with `/bin`, `/etc`, `/lib`, `/mnt`, `/sbin`, `/usr`, and `/var` available for listing. The `/sbin` directory contained `anyka_ipc.sh`, `udisk.sh`, `update.sh`, `service.sh`, and related helper scripts used during camera startup.

The active config file on the camera had `rtsp_support = 1` under `[global]` and `onvif = 1` under `[cloud]`, proving that RTSP and ONVIF were enabled in configuration. The camera firmware also contained `libOnvif.so`, `librtsp.so`, `libakmedialib.so`, and `libakstreamenclib.so`, which confirms the local ONVIF and RTSP stacks are present in the firmware image.

Despite those settings, a port scan showed ports 80, 554, 7070, 8554, and 37777 all closed, which indicates that the expected services were not actually binding sockets at runtime. The startup script explains why this matters: it launches `cmd` and `discovery` only if `[cloud].onvif` is set to `1`, then attempts to start `anyka_ipc` in the background.

## Phase 1: verify FTP and inventory the camera

Before changing anything, verify that FTP works and save a snapshot of the filesystem layout. This gives a baseline and confirms whether the camera matches the same model family and script layout as the reference unit.

Use the following probe script:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-192.168.1.34}"
USER_NAME="${2:-admin}"
PASS="${3:-}"
OUTDIR="${4:-camera_probe_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

SESSION="$OUTDIR/session.txt"
HITS="$OUTDIR/hits.txt"
USR_BIN="$OUTDIR/usr_bin.txt"
USR_SBIN="$OUTDIR/usr_sbin.txt"
LIB="$OUTDIR/lib.txt"
USR_LIB="$OUTDIR/usr_lib.txt"
SUMMARY="$OUTDIR/summary.txt"

ftp -inv "$HOST" <<FTP_CMDS > "$SESSION" 2>&1
quote USER $USER_NAME
quote PASS $PASS
pwd
dir /
dir /bin
dir /sbin
dir /usr
dir /usr/bin
dir /usr/sbin
dir /lib
dir /usr/lib
bye
FTP_CMDS

awk '
  /^150 Directory listing/ {capture=1; section++; next}
  /^226 / {capture=0; print ""; next}
  capture {print}
' "$SESSION" > "$OUTDIR/all_dir_content.txt"

awk '
  {
    name=$NF
    if (name != "" && $1 ~ /^[-dl]/) print name
  }
' "$OUTDIR/all_dir_content.txt" | sort -u > "$OUTDIR/all_names.txt"

grep -E '(^|/)(anyka_ipc|anyka_ipc\.sh|cmd|discovery|onvif|rtsp|rtspd|libOnvif\.so|librtsp\.so|busybox|ftpd|telnetd)$' \
  "$OUTDIR/all_names.txt" > "$HITS" || true

awk '
  /^150 Directory listing/ {section++ ; capture=1; next}
  /^226 / {capture=0; next}
  capture && section==5 {print}
' "$SESSION" > "$USR_BIN"

awk '
  /^150 Directory listing/ {section++ ; capture=1; next}
  /^226 / {capture=0; next}
  capture && section==6 {print}
' "$SESSION" > "$USR_SBIN"

awk '
  /^150 Directory listing/ {section++ ; capture=1; next}
  /^226 / {capture=0; next}
  capture && section==7 {print}
' "$SESSION" > "$LIB"

awk '
  /^150 Directory listing/ {section++ ; capture=1; next}
  /^226 / {capture=0; next}
  capture && section==8 {print}
' "$SESSION" > "$USR_LIB"

{
  echo "=== KEY HITS ==="
  cat "$HITS" 2>/dev/null || true
  echo
  echo "=== ONVIF/RTSP LIBRARY LINES ==="
  grep -Ei 'onvif|rtsp|stream|media|ipc' "$USR_LIB" || true
  echo
  echo "=== anyka_ipc RELATED ==="
  grep -Ei 'anyka|ipc|cmd|discovery' "$USR_BIN" "$USR_SBIN" || true
} > "$SUMMARY"

echo "[+] Saved raw session to: $SESSION"
echo "[+] Saved summary to: $SUMMARY"
```

Run it like this:

```bash
chmod +x probe_camera_ftp.sh
./probe_camera_ftp.sh 192.168.1.34 admin ""
```

A camera that matches the reference model should show `anyka_ipc.sh` in `/sbin` and `libOnvif.so` plus `librtsp.so` in `/usr/lib`.

## Phase 2: fetch the live config and startup script

The next step is to verify the exact config file the camera is using and read the startup wrapper that launches the camera daemon. On the reference unit, the live config was `/etc/jffs2/anyka_cfg.ini`, and the wrapper script was `/usr/sbin/anyka_ipc.sh`.

Use this script to download both files:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-192.168.1.34}"
USER_NAME="${2:-admin}"
PASS="${3:-}"
OUTDIR="${4:-anyka_rtsp_check_$(date +%Y%m%d_%H%M%S)}"

mkdir -p "$OUTDIR"

ftp -inv "$HOST" <<FTP_CMDS
user $USER_NAME $PASS
binary
get /etc/jffs2/anyka_cfg.ini $OUTDIR/anyka_cfg_from_cam.ini
get /usr/sbin/anyka_ipc.sh $OUTDIR/anyka_ipc.sh
bye
FTP_CMDS
```

After downloading them, verify these two conditions:

- `rtsp_support = 1` under `[global]`.
- `onvif = 1` under `[cloud]`.

On the reference device, `anyka_ipc.sh` did the following:

```sh
inifile="/etc/jffs2/anyka_cfg.ini"
onvif=`awk 'BEGIN {FS="="}/\[cloud\]/{a=1} a==1&&$1~/onvif/{...}' $inifile`
if [ "$onvif" = "1" ]
then
    cmd &
    discovery &
fi

pid=`pgrep anyka_ipc`
if [ "$pid" = "" ]
then
    anyka_ipc &
fi
```

This means ONVIF controls whether `cmd` and `discovery` launch, while `anyka_ipc` is always attempted during `start`.

## Phase 3: gain telnet access by replacing `/etc/jffs2/shadow`

If telnet is listening but the password is unknown, the cleanest recovery path is to back up `/etc/jffs2/shadow`, generate a known replacement hash for the `root` account, upload the modified file over FTP, and reboot the camera.

The following script performs the backup and replacement safely:

```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-192.168.1.34}"
FTP_USER="${2:-admin}"
FTP_PASS="${3:-}"
NEWPASS="${4:-}"
OUTDIR="${5:-shadow_work_$(date +%Y%m%d_%H%M%S)}"

if [ -z "$NEWPASS" ]; then
  echo "Usage: $0 <host> <ftp_user> <ftp_pass> <new_root_password> [outdir]"
  echo "Example: $0 192.168.1.34 admin \"\" MyNewPass123"
  exit 1
fi

mkdir -p "$OUTDIR"
BACKUP="$OUTDIR/shadow.backup"
EDITED="$OUTDIR/shadow.edited"
LOG="$OUTDIR/ftp_shadow.log"

echo "[*] Backing up /etc/jffs2/shadow from $HOST ..."

ftp -inv "$HOST" <<FTP_CMDS > "$LOG" 2>&1
user $FTP_USER $FTP_PASS
binary
get /etc/jffs2/shadow $BACKUP
bye
FTP_CMDS

if [ ! -s "$BACKUP" ]; then
  echo "[!] Failed to download /etc/jffs2/shadow"
  echo "[!] Check $LOG"
  exit 2
fi

echo "[+] Backup saved to $BACKUP"
echo "[*] Generating MD5-crypt hash for new root password..."
HASH="$(openssl passwd -1 "$NEWPASS")"

echo "[*] Rewriting root hash..."
awk -F: -v OFS=: -v H="$HASH" '
  $1=="root" {$2=H}
  {print}
' "$BACKUP" > "$EDITED"

echo "[*] Uploading edited shadow back to camera ..."
ftp -inv "$HOST" <<FTP_CMDS >> "$LOG" 2>&1
user $FTP_USER $FTP_PASS
binary
put $EDITED /etc/jffs2/shadow
bye
FTP_CMDS

echo "[+] Upload attempted. See log: $LOG"
echo "[*] Reboot the camera, then log in via telnet as root using the password you chose."
```

Run it like this:

```bash
chmod +x backup_set_telnet_shadow.sh
./backup_set_telnet_shadow.sh 192.168.1.34 admin "" MyNewPass123
```

This approach edits only the `root` line and preserves the rest of the BusyBox-compatible shadow format. The hash generation uses `openssl passwd -1`, which produces MD5-crypt output compatible with older embedded Linux systems like these cameras.

### Telnet login check

After rebooting the camera, try:

```bash
telnet 192.168.1.34
```

Then log in as:

- user: `root`
- password: the password passed to the script

If `/etc/jffs2/shadow` is not writable or the upload path fails, test whether the platform instead stores the shadow file at `/etc/jffs/shadow`, which is a variant reported on related Anyka devices.

## Phase 4: verify the shell and make a full safety backup

As soon as telnet works, create a backup directory on the SD card or in `/tmp` and save copies of the critical files before making service changes.

Recommended backup commands from the telnet shell:

```sh
mkdir -p /mnt/backup_unlock
cp /etc/jffs2/anyka_cfg.ini /mnt/backup_unlock/
cp /etc/jffs2/shadow /mnt/backup_unlock/
cp /usr/sbin/anyka_ipc.sh /mnt/backup_unlock/
cp /sbin/service.sh /mnt/backup_unlock/ 2>/dev/null || true
cp /sbin/update.sh /mnt/backup_unlock/ 2>/dev/null || true
cp /sbin/udisk.sh /mnt/backup_unlock/ 2>/dev/null || true
cp /etc/inittab /mnt/backup_unlock/ 2>/dev/null || true
```

The reference camera exposed `anyka_ipc.sh`, `service.sh`, `udisk.sh`, and `update.sh` through FTP, so these are the first files worth preserving before changes are made.

## Phase 5: confirm whether `anyka_ipc` is running

On the reference camera, the live config enabled ONVIF and RTSP, but a network scan still showed all common service ports closed, which strongly suggests that `cmd`, `discovery`, and `anyka_ipc` were either not launched or exited immediately.

From the telnet shell, check process state:

```sh
ps | grep -E 'anyka_ipc|cmd|discovery'
```

Expected outcome on a healthy device after startup:

- `cmd` running when `onvif = 1`.
- `discovery` running when `onvif = 1`.
- `anyka_ipc` running in all normal cases.

If none of them are running, manually test the startup wrapper:

```sh
/usr/sbin/anyka_ipc.sh start
sleep 3
ps | grep -E 'anyka_ipc|cmd|discovery'
netstat -lnpt 2>/dev/null | grep -E ':80|:554|:8554|:7070|:37777'
```

Then, from another machine on the LAN, run:

```bash
nmap -sV -p 80,554,8554,7070,37777 192.168.1.34
```

On the reference camera before manual intervention, ports 80, 554, 7070, 8554, and 37777 were all closed. If they open after a manual start, the problem is a boot-time launch issue rather than a missing binary or missing library.

## Phase 6: inspect why `anyka_ipc` fails

The likely failure mode on this model family is that `anyka_ipc` tries to contact a remote cloud endpoint and becomes stuck or exits before local services bind. Similar Anyka camera investigations report cloud-first startup behavior and hard dependencies on vendor endpoints for normal boot flow.

Useful shell commands for diagnosis are:

```sh
logread | tail -n 100
logread | grep -i anyka
ps w
strings /usr/bin/anyka_ipc | grep -Ei 'http|https|cloud|dana|tutk|onvif|rtsp' | head -n 100
```

Also inspect the live config values that may influence cloud behavior:

```sh
grep -A5 '^\[cloud\]' /etc/jffs2/anyka_cfg.ini
```

On the reference camera, `[cloud]` contained `dana = 1`, `onvif = 1`, `tutk = 0`, `tencent = 0`, and `hk = 1`. If local services do not come up until cloud backends answer, reducing or disabling nonessential cloud flags may be required, but the original config should always be backed up first.

## Phase 7: test conservative config changes

After a full backup, the safest first change is to preserve ONVIF while reducing cloud-specific dependencies. On the analyzed camera, the minimal values of interest were:

```ini
[global]
rtsp_support = 1

[cloud]
onvif = 1
dana = 0
hk = 1
tutk = 0
tencent = 0
```

This is a conservative test because it keeps the local discovery path enabled while removing cloud vendor backends that are not required for plain RTSP/ONVIF operation. After editing `/etc/jffs2/anyka_cfg.ini`, restart the daemon or reboot the camera:

```sh
/usr/sbin/anyka_ipc.sh restart
# or
reboot
```

Then repeat:

```sh
ps | grep -E 'anyka_ipc|cmd|discovery'
netstat -lnpt 2>/dev/null | grep -E ':80|:554|:8554|:7070|:37777'
```

and from the LAN:

```bash
nmap -sV -p 80,554,8554,7070,37777 192.168.1.34
```

## Notes specific to this model family

The reference camera is an Anyka AK3916/AK3918-family board exposing a typical BusyBox-based root filesystem and cloud-centric camera stack. The startup wrapper clearly ties local ONVIF helper daemons to the `[cloud].onvif` flag and then attempts to launch `anyka_ipc`, so successful local streaming depends on more than just setting `rtsp_support = 1` in the config.

That detail is the most important takeaway for unlocking another camera of the same family: if RTSP stays closed even with the right config, the priority should shift from editing anyka_cfg.ini to proving that anyka_ipc.sh start actually runs successfully and that anyka_ipc is not stalling on cloud initialization.

---

« [Table of Contents](../README.md) | [Chapter 01: Device Specs and Firmware Layout](01-device-specs.md) »
