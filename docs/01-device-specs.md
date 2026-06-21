# 01 — Device Specs and Firmware Layout

## Confirmed characteristics

- ELF daemon: 32-bit ARM EABI5, stripped (`anyka_ipc`)
- Typical libs present: ONVIF + RTSP stack
- Init chain: `init -> /etc/init.d/rcS -> /etc/init.d/rc.local -> /usr/sbin/service.sh start`
- IPC launch path: `/usr/sbin/service.sh -> /usr/sbin/anyka_ipc.sh -> anyka_ipc`

## Partition/mount model

```text
/dev/root      -> /            squashfs (ro)
/dev/mtdblock2 -> /usr         squashfs (ro)
/dev/mtdblock3 -> /etc/jffs2   jffs2 (rw)
/dev/mmcblk0p1 -> /mnt         exfat/vfat (rw)
```

Implication: runtime edits to `/usr/bin/anyka_ipc` are not persistent. Persistent daemon customization requires rebuilding/flashing `usr.sqsh4`.

---

« [Chapter 00: Gaining Telnet Access](00-anyka-gain-access.md) | [Table of Contents](../README.md) | [Chapter 02: Toolchain and Prerequisites](02-toolchain-and-prereqs.md) »

