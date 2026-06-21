# 05 — Build and Repack `usr.sqsh4`

This guide explains how to extract, patch, customize, and rebuild the `/usr` filesystem (`usr.sqsh4`) for the Anyka camera.

---

## 1) Dump Original `/usr` Partition from Camera

First, dump the current SquashFS image from the running camera (ensure you have Telnet/SSH access as detailed in [Chapter 00](00-anyka-gain-access.md)).

```sh
# Run this on the camera via Telnet
dd if=/dev/mtdblock2 of=/mnt/usr.sqsh4 bs=1M
sync
md5sum /mnt/usr.sqsh4
```

Copy the generated `/mnt/usr.sqsh4` file from the camera's SD card to your host Linux machine.

---

## 2) Unpack the SquashFS Image on Host

On your Linux host, extract the filesystem:

```bash
unsquashfs -d usr_sqsh4_root usr.sqsh4
```

This creates a folder named `usr_sqsh4_root` containing the camera's userspace layout:
- System binaries are in `usr_sqsh4_root/bin/`
- Service/startup scripts are in `usr_sqsh4_root/sbin/`

---

## 3) Replace Daemon Binary

Overwrite the default stripped daemon with your patched binary (as detailed in [Chapter 03](03-anyka-ipc-binary-patch.md)):

```bash
cp anyka_ipc.patched usr_sqsh4_root/bin/anyka_ipc
chmod 755 usr_sqsh4_root/bin/anyka_ipc
```

---

## 4) Apply Startup Customizations

Copy the helper scripts provided in this repository's `scripts/` directory to their corresponding locations in the extracted SquashFS root.

Run the following commands from the root directory of this repository:

```bash
# 1. Copy the patched service scripts and hooks
cp scripts/sbin_anyka_ipc.sh usr_sqsh4_root/sbin/anyka_ipc.sh
cp scripts/sbin_start_ipc_hook.sh usr_sqsh4_root/sbin/start_ipc_hook.sh
cp scripts/sbin_restart_ipc_hook.sh usr_sqsh4_root/sbin/restart_ipc_hook.sh
cp scripts/sbin_seed_wifi_cfg.sh usr_sqsh4_root/sbin/seed_wifi_cfg.sh
cp scripts/sbin_service.sh usr_sqsh4_root/sbin/service.sh

# 2. Make all copied scripts executable
chmod 755 usr_sqsh4_root/sbin/anyka_ipc.sh
chmod 755 usr_sqsh4_root/sbin/start_ipc_hook.sh
chmod 755 usr_sqsh4_root/sbin/restart_ipc_hook.sh
chmod 755 usr_sqsh4_root/sbin/seed_wifi_cfg.sh
chmod 755 usr_sqsh4_root/sbin/service.sh
```

---

## 5) Repack the SquashFS Filesystem

Pack the `usr_sqsh4_root` folder back into a SquashFS image. The image **must** use the `xz` compression format, a block size of `128K` (`131072`), and have all files owned by root:

```bash
mksquashfs usr_sqsh4_root usr.sqsh4.patched -comp xz -b 131072 -noappend -all-root
md5sum usr.sqsh4.patched > usr.sqsh4.patched.md5
```

---

## 6) Sanity Checks

Verify that the repacked file structure and permissions are correct before attempting to flash:

```bash
# Check block size and compression parameters
unsquashfs -s usr.sqsh4.patched

# Unpack and verify specific critical files
unsquashfs -d verify_root -f usr.sqsh4.patched sbin/anyka_ipc.sh sbin/start_ipc_hook.sh sbin/restart_ipc_hook.sh sbin/seed_wifi_cfg.sh bin/anyka_ipc

# Confirm binary integrity
md5sum anyka_ipc.patched verify_root/bin/anyka_ipc
```

Once validated, proceed to [Chapter 06: Flash and Validate](06-flash-and-validate.md) to apply the firmware to your device.

---

« [Chapter 04: Firmware Customizations](04-firmware-customizations.md) | [Table of Contents](../README.md) | [Chapter 06: Flash and Validate](06-flash-and-validate.md) »
