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

You’ve seen **`probe failed error -110`** / timeouts. **Full power-off** (not soft reboot) often recovers. For development: **reseating** the module, **better PSU**, **cooling**, and **kernel/firmware** updates on the card.

## Mitigation C — empty / broken mesh files

If `/etc/default/mesh` or `wpa_supplicant-wlan*.conf` are **0 bytes**, services can misbehave. Restore from `/etc/mesh.conf` (see `device-diagnostics-notes.md`) or re-run **`radio-setup.sh`** when the link is stable.

## When SSH is dead

Use **USB-serial to CM4 UART** to capture **last kernel lines** and confirm **watchdog reset** vs **Ethernet only**.
