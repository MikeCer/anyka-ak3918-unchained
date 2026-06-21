# 02 — Toolchain and Prerequisites

## Host tools

```bash
sudo apt-get update
sudo apt-get install -y squashfs-tools binutils-arm-linux-gnueabi gdb-multiarch
```

Required binaries:

- `unsquashfs`, `mksquashfs`
- `arm-linux-gnueabi-objdump`
- `md5sum`

## Camera-side prerequisites

- Working update trigger (physical update button + SD card)
- SD card mounted at `/mnt`
- `update.sh` available at `/usr/sbin/update.sh`

## Safety checklist

1. Keep original `usr.sqsh4` and checksums.
2. Keep one known-good recovery SD card ready.
3. Change one customization at a time, validate, then proceed.

---

« [Chapter 01: Device Specs](01-device-specs.md) | [Table of Contents](../README.md) | [Chapter 03: Binary Patching](03-anyka_ipc-binary-patch.md) »

