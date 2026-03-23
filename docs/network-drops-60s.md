# Network dies after ~1 minute (CM4 / Pi + mesh)

## Likely cause

Raspberry Pi OS runs **systemd with the Broadcom hardware watchdog** (often **~60s**). If the kernel **hangs** or **stops pinging the watchdog** (PCIe Wi‑Fi / `mt7915e` wedge, driver bug, storage stall), the SoC **resets** — looks like “SSH works, then everything drops.”

This is **not** your mesh scripts timing out at 60s; it’s usually **reset** or **link loss**.

## Fast checks (when you have any shell: SSH, serial, keyboard)

```bash
vcgencmd get_throttled
dmesg -T | tail -30
journalctl -b -0 -k --no-pager | tail -40
```

## Mitigation A — prove watchdog (debug builds only)

**Disable systemd’s use of the hardware watchdog** so a hang doesn’t reboot the board (you’ll get a **stuck** machine instead — use **serial console**).

```bash
sudo mkdir -p /etc/systemd/system.conf.d
printf '%s\n' '[Manager]' 'RuntimeWatchdogSec=0' 'RebootWatchdogSec=0' | sudo tee /etc/systemd/system.conf.d/10-disable-watchdog.conf
sudo systemctl daemon-reload
# Reboot once so kernel/watchdog policy matches your image
sudo reboot
```

Revert by removing that drop-in and `daemon-reload` + reboot.

## Mitigation B — PCIe Wi‑Fi (`mt7915e`)

You’ve seen **`probe failed error -110`** (firmware talk timeout) and sometimes **`-12` (ENOMEM)** during probe. **`dmesg`** may show **`irq 26: nobody cared`** / **`Disabling IRQ #26`** (PCIe **AER** on CM4) right before **`mt7915e` fails** — try **`pci=nomsi`** in `/boot/firmware/cmdline.txt` (see [`device-diagnostics-notes.md`](device-diagnostics-notes.md)). **Full power-off** (not soft reboot) often recovers. For development: **reseating** the **module and M.2 adapter**, **3.3 V / PSU headroom** (see [AW7916-AED power notes](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/)), **heatsink**, and **kernel/firmware** updates.

**Not the same as “~60s drop”:** A **`Kernel panic - not syncing: Asynchronous SError Interrupt`** with stack through **`mt7915_update_channel`** / **`mt7915_mac_work`** (often **`phy2`**) is a **documented ramoops capture** — driver/MMIO on the **MediaTek** path, not systemd’s **60s hardware watchdog** firing on a silent hang. See **[Example capture (field): … mt7915_update_channel …](device-diagnostics-notes.md#example-capture-field-asynchronous-serror-during-mt7915_update_channel-phy2-mt7915_mac_work)** in `device-diagnostics-notes.md`.

## Mitigation C — empty / broken mesh files

If `/etc/default/mesh` or `wpa_supplicant-wlan*.conf` are **0 bytes**, services can misbehave. Restore from `/etc/mesh.conf` (see `device-diagnostics-notes.md`) or re-run **`radio-setup.sh`** when the link is stable.

## When SSH is dead

Use **USB-serial to CM4 UART** to capture **last kernel lines** and confirm **watchdog reset** vs **Ethernet only**.
