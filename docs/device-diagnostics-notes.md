# CM4 mesh node — diagnostics summary (field notes)

Reference for future sessions. Last updated from checks against a **Raspberry Pi Compute Module 4 Rev 1.1** mesh image (Mar 2026).

## Hardware assumptions

- **Morse HaLow (802.11ah) is not connected.** Kernel messages such as `morse_spi_probe: failed to init SPI with CMD63` / probe **-61** are **expected** when no Morse module is present on SPI. Do not treat those as a regression unless a HaLow board is actually installed.

## Access

- SSH user: **`radio`** (root SSH was denied in our tests — likely disabled).
- Non-interactive SSH: **`iw`** and **`rfkill`** live under `/usr/sbin`. Use  
  `export PATH="/usr/sbin:/sbin:$PATH"`  
  or call `/usr/sbin/iw` explicitly.

## Provisioning logs (typical locations)

| Path | Notes |
|------|--------|
| `/boot/firmware/firstrun.log` | First-boot script: user `radio`, SSH, `mesh-provision`, cleanup. |
| `/boot/firmware/provision.log` | Main provisioning (not `provison.log` — common typo). |
| `/var/log/radio-setup.log` | Post-boot radio / interface setup (mesh/AP selection). |

**Observed once:** firstrun and main provisioning completed (`Provisioning complete …`, `mesh-provision` disabled, reboot). Minor non-fatal noise: `dhcpcd` unit missing; optional `10-end1.network` copy failed if file absent on image.

**radio-setup:** Requires wireless PHYs. If **`iw dev`** shows no interfaces, setup can end with **no mesh/AP interfaces** and errors like **“No suitable interface found for AP”** when `eud=wireless`.

## How to check Wi‑Fi radios (quick checklist)

```bash
export PATH="/usr/sbin:/sbin:$PATH"
iw dev
iw phy
ip -br link
rfkill list
iw reg get
dmesg -T | grep -iE 'mt79|7915|wlan|brcmf|cfg80211|morse'
lsmod | grep -iE 'mac80211|cfg80211|mt79|brcmf|morse'
lspci | grep -i network    # PCIe Wi‑Fi
lsusb                      # USB Wi‑Fi
```

## What we saw on the reference unit (Wi‑Fi)

| Component | Observation |
|-----------|----------------|
| **PCIe Wi‑Fi** | `lspci`: **MediaTek 14c3:7906** (MT7915/7916 family). Driver **`mt7915e`** loads firmware, then **probe fails**: `Message 000101ed (seq 4) timeout` → **error -110 (ETIMEDOUT)**. **No `wlan` interface** created. |
| **Built-in Wi‑Fi** | **No `brcmfmac`** in use, no `wlan*` in `/sys/class/net`. Consistent with **CM4 without wireless** or Wi‑Fi not enabled — do not assume internal 802.11 until `brcmfmac` + `wlan0` appear in `dmesg`/`iw dev`. |
| **Morse HaLow** | Driver may log SPI probe failures; **ignore for bench diagnosis** when no HaLow hardware is connected (see above). |

## Useful follow-ups when PCIe Wi‑Fi times out

- Reseat module, cold power cycle, carrier-specific PCIe power/reset notes.
- After boot: `dmesg | grep -E 'mt7915|7915|7906'` and compare firmware filenames (`modinfo mt7915e`) vs vendor expectations.
- **Security:** provisioning logs may contain mesh/AP keys — rotate if logs are shared.

## Kernel log snapshot (grabbed from device)

- **`kernel-log-snapshot.txt`** — optional local copy of `journalctl -k -b 0` (not committed; listed in `.gitignore`). Regenerate after incidents if you keep a copy beside this doc.

### Previous boot (`journalctl -b -1 -k`)

**New images:** `firstrun.sh` (from `MANET/provisioning/firstrun.sh.template`) installs `/etc/systemd/journald.conf.d/40-rpi-volatile-storage.conf` with **`Storage=persistent`** on first boot so journals land under **`/var/log/journal/<machine-id>/`**.

**Raspberry Pi OS** ships `/usr/lib/systemd/journald.conf.d/40-rpi-volatile-storage.conf` with **`Storage=volatile`**, so logs stay under `/run` unless overridden. If **`journalctl -u systemd-journald`** still says only **Runtime Journal** and **`/var/log/journal/<machine-id>/` never appears** (e.g. old image), **shadow the RPi file** in `/etc` (same filename replaces the vendor intent cleanly):

```bash
sudo mkdir -p /etc/systemd/journald.conf.d /var/log/journal
sudo tee /etc/systemd/journald.conf.d/40-rpi-volatile-storage.conf >/dev/null <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=100M
RuntimeMaxUse=50M
EOF
sudo chown root:systemd-journal /var/log/journal
sudo chmod 2755 /var/log/journal
sudo systemctl restart systemd-journald
# Confirm: should see "Persistent Journal" and a directory under /var/log/journal/<machine-id>/
sudo ls -la /var/log/journal/
```

After that survives a **reboot**, `journalctl -b -1 -k` can show the **previous** boot’s kernel log.

### When the node is down (no SSH)

- **Power / link:** cold cycle, Ethernet cable, PoE if applicable.
- **Logs without network:** mount the SD card on a PC and copy **`var/log/journal/`** (if persistent journaling was working) or **`/boot/firmware/*.log`** and **`var/log/radio-setup.log`**.
- If the journal was still **volatile**, the previous boot is **gone** unless you had **serial console** logging or **remote syslog**.

## Mesh stack (symptoms vs fixes in-tree)

Field journals showed **`batman-enslave` failing** with **`/etc/default/mesh not found`**, **`bat0` missing**, and **`node-manager`** editing **non-existent** `wpa_supplicant-wlan*.conf` when PCIe Wi‑Fi was flaky or still coming up.

| Symptom | Cause | Change |
|--------|--------|--------|
| `Mesh configuration /etc/default/mesh not found` | File was only written **inside** the wlan loop; empty `mesh_if` → file never created | **`radio-setup.sh`** writes `/etc/default/mesh` as soon as **`MESH_NAME`** is set from `mesh.conf` |
| `integer expression expected` on PHY wait | `grep -c` prints `0` with exit 1, then `|| echo 0` appended a second line | **`radio-setup.sh`** uses `grep -c … \|\| true` only |
| `sed: can't read … wpa_supplicant-wlan0.conf` | Static/ACS node-manager assumed configs existed | **`node-manager-static.sh`** / **`node-manager-acs.sh`** skip `sed`/restarts if conf files are missing |

Unclean power-downs still produce **journal corruption** lines on the next boot; that is separate from mesh config logic.

## Related repo paths

- Provisioning scripts/docs: `MANET/provisioning/`
