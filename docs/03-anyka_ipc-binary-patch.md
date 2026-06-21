# 03 — `anyka_ipc` Binary Patching (Reverse-Engineering Tutorial)

This chapter explains the full RE path used to derive the SCC bypass patch, not just the final byte edit.

---

## 1) Goal and observed runtime behavior

Observed startup behavior on this firmware family:

1. `anyka_ipc` initializes camera/audio subsystems.
2. SCC/cloud init runs (`scc init ...`).
3. If SCC path fails, startup can abort before local services are usable.
4. RTSP/ONVIF availability then depends on this cloud gate.

Target: force `anyka_ipc` to continue local startup even if SCC module init returns failure.

---

## 2) Recon from logs + strings

First, correlate logs with binary strings:

```bash
strings -a anyka_ipc | grep -E "scc init|scc init fail|scc init success|rtsp server listen"
```

In our reference binary, these key markers exist:

- `scc init`
- `scc init fail`
- `scc init success`

That gives an anchor to locate the SCC decision block in code.

---

## 3) Identify architecture and disassembly tools

```bash
file anyka_ipc
```

Expected:

- ELF 32-bit ARM EABI5, stripped

Use ARM-aware disassembly:

- `arm-linux-gnueabi-objdump`
- `readelf`

---

## 4) Map virtual address ↔ file offset

Get sections:

```bash
readelf -S anyka_ipc
```

For this sample:

- `.text` VA start: `0x00045280`
- `.text` file offset: `0x03d280`

Mapping formula:

```text
file_off = text_off + (va - text_va)
```

---

## 5) Locate SCC function and decision block

Even stripped binaries here expose many dynamic symbols:

```bash
readelf -s anyka_ipc | grep -E "scc_init|sccModuInit"
```

Disassemble around `scc_init`:

```bash
arm-linux-gnueabi-objdump -d anyka_ipc --start-address=0x5bf74 --stop-address=0x5c560
```

Critical sequence found:

```asm
5c434:  bl   688dc <sccModuInit>
5c438:  cmp  r0, #0
5c43c:  bge  5c458
...
5c454:  b    5bfb4      ; failure path
5c458:  ...             ; success/continue path
```

Interpretation:

- `sccModuInit` result in `r0`
- `r0 >= 0` goes to continue path
- negative result triggers fail/cleanup/exit route

This is exactly the cloud gate we need.

---

## 6) Derive minimal patch

We do not change control-flow size, only branch condition:

- Original opcode at `0x5c43c`: `aa000005` (`bge +5`)
- Desired opcode: `ea000005` (`b +5`, unconditional)

Only the high byte changes from `0xaa` to `0xea` in little-endian word encoding.

### Compute file offset

```text
va = 0x5c43c
file_off = 0x3d280 + (0x5c43c - 0x45280) = 0x5443c
```

In little-endian bytes, the 4-byte word is at `0x5443c..0x5443f`; the condition nibble change lands at `0x5443f`.

---

## 7) Apply one-byte patch

```bash
cp anyka_ipc anyka_ipc.patched
printf '\xea' | dd of=anyka_ipc.patched bs=1 seek=$((0x5443f)) conv=notrunc status=none
```

---

## 8) Validate static patch integrity

Disassemble the patched window:

```bash
arm-linux-gnueabi-objdump -d anyka_ipc.patched --start-address=0x5c430 --stop-address=0x5c460
```

Expected line:

```asm
5c43c:  ea000005    b 5c458
```

Optional raw byte check:

```bash
xxd -g 4 -s 0x54430 -l 32 anyka_ipc.patched
```

---

## 9) Runtime validation criteria

After deploying patched binary, success signals are:

1. Process remains alive (`ps | grep anyka_ipc`)
2. Logs show SCC init sequence without fatal exit
3. RTSP server binds (`rtsp server listen sucess`)
4. RTSP handshake works on channel paths (`ch0_0.264`, `ch0_1.264`)

---

## 10) Why this patch is robust

- Minimal blast radius: one conditional branch byte.
- No instruction length changes.
- No relocation/import impact.
- Preserves all downstream initialization logic.

Tradeoff:

- You skip SCC failure handling path intentionally; this is acceptable for local-only operation but should be documented for maintainers.

---

## 11) Repro checklist

1. Confirm ARM ELF.
2. Locate `scc_init` and `sccModuInit` callsite.
3. Verify `cmp r0,#0` + `bge` gate to success path.
4. Patch `bge` → `b`.
5. Re-disassemble and confirm opcode.
6. Validate runtime service bring-up.

---

« [Chapter 02: Toolchain and Prerequisites](02-toolchain-and-prereqs.md) | [Table of Contents](../README.md) | [Chapter 04: Firmware Customizations](04-firmware-customizations.md) »
