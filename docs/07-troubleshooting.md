# 07 — Troubleshooting

## 1) `anyka_ipc` not auto-starting after reboot

Check path mismatches:

- Hook references must use `/usr/sbin/...` (not `/sbin/...` at runtime).

Validate:

```sh
grep -n 'START_HOOK\|RESTART_HOOK' /usr/sbin/anyka_ipc.sh
```

## 2) Hook executes but daemon not running

Run hook manually:

```sh
/usr/sbin/start_ipc_hook.sh
ps | grep anyka_ipc | grep -v grep
```

If manual start works, check service startup ordering and monitor restarts.

## 3) RTSP advertises URI but client fails

Use channel endpoints directly:

- `ch0_0.264` (main)
- `ch0_1.264` (sub)

## 4) ONVIF stream URI has stale IP

Verify `/etc/jffs2/config.xml` was rewritten by startup hook and current interface has an IP when hook runs.

## 5) Wi-Fi still not joining AP

Confirm seeding script wrote values:

```sh
grep -A8 '^\[wireless\]' /etc/jffs2/anyka_cfg.ini
cat /tmp/wifi_seed.log 2>/dev/null
```

## 6) Recovery

- Reflash known-good `usr.sqsh4`
- Keep immutable backup of original dump and md5

---

« [Chapter 06: Flash and Validate](06-flash-and-validate.md) | [Table of Contents](../README.md) »

