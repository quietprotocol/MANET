# CM4 mesh node — diagnostics summary (field notes)

Reference for future sessions. Last updated from checks against a **Raspberry Pi Compute Module 4 Rev 1.1** mesh image (Mar 2026).

### Current bench profile (read this first)

Recent CM4 bench nodes target **mesh backhaul on PCIe M.2 only** (**[524WiFi AW7916-AED](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/)** + [AliExpress M.2 adapter](https://www.aliexpress.com/item/4000175123887.html?spm=a2g0o.order_list.order_list_main.66.787318027rHYJu) in [Waveshare CM4-IO-BASE-B](https://www.waveshare.com/cm4-io-base-b.htm) **M-key** slot): **`dtoverlay=disable-wifi`** (onboard SDIO Wi-Fi off), **Morse SPI / HaLow and camera autoload off** in `config.txt`, and **Morse modules blacklisted** where applied. On that profile, **skip `mmc1` / `brcmfmac` / CM4 U.FL** troubleshooting unless you re-enable onboard Wi-Fi.

## Hardware assumptions

- **Morse HaLow (802.11ah):** On Morse-oriented images with **no module on SPI**, `morse_spi_probe …` **-61** is **expected** noise. If Morse is **disabled in firmware** and **blacklisted**, those lines may **not appear**.

### Reference module SKU

Bench notes match **CM4108032** ([Raspberry Pi product listing](https://www.raspberrypi.com/products/compute-module-4/?variant=raspberry-pi-cm4108032)): **8GB RAM**, **32GB eMMC**, **onboard 2.4 / 5 GHz Wi‑Fi (802.11ac)** and **Bluetooth 5.0** (hardware present). **When onboard Wi-Fi is enabled in device-tree** (`disable-wifi` **not** set), **`mmc1` + `brcmfmac` + SDIO `wlan*` are expected** if wiring and antenna are correct — do not dismiss missing onboard `wlan*` as "CM4 without wireless." With **`disable-wifi`**, no SDIO `wlan*` is **intentional**. Part-number decoding (**CM4** / **1**=wireless / **08**=8GB / **032**=32GB eMMC) matches Table 9–10 in the [CM4 datasheet PDF](https://pip-assets.raspberrypi.com/categories/634-raspberry-pi-compute-module-4/documents/RP-008168-DS-2-cm4-datasheet.pdf).

### CM4 datasheet (official)

**[Compute Module 4 datasheet (PDF)](https://pip-assets.raspberrypi.com/categories/634-raspberry-pi-compute-module-4/documents/RP-008168-DS-2-cm4-datasheet.pdf)** — use for pinout, RF, and PCIe rules. Diagnostics-oriented excerpts:

- **Onboard vs external antenna:** The module can use a **PCB trace antenna** or a **U.FL** external antenna; selection is **fixed at boot** via `config.txt`: **`dtparam=ant1`** (internal) or **`dtparam=ant2`** (external). Wrong choice for how the hardware is actually wired can make Wi‑Fi look dead or very weak.
- **`WL_nDisable` / `BT_nDisable`:** If a carrier ties either **low**, the respective radio is **held off** (datasheet §2.1.1–2.1.2). **Floating** is OK (internal pull-ups). Suspect the base board if SDIO Wi‑Fi never powers but Bluetooth paths behave oddly.
- **PCIe (Gen 2 ×1):** Follow **clock request** and **reset** wiring on custom designs; on a commercial IO board this is already handled. If a device misbehaves on interrupts, the datasheet notes **`pci=nomsi`** on the kernel command line as a common experiment (§2.3).
- **Mechanical / RF:** On-board antenna needs **clearance** from metal / ground fill (datasheet §3.1); poor enclosure layout hurts 2.4 GHz especially. Prefer **certified antenna kits** if you are not reusing Pi’s own RF layout.
- **Power:** **+5 V** should stay **≥4.75 V** under load; typical operating current order of **~1.4 A** cited in the doc — relevant when **USB + M.2 + radios** stack on a **5 V / 2.5 A** class adapter (see carrier notes below).

### Reference carrier board

**[Waveshare CM4-IO-BASE-B](https://www.waveshare.com/cm4-io-base-b.htm)** (“Mini Base Board B”): **M.2 M key** slot (per Waveshare: NVMe **or** PCIe **M-key** communication modules), **Gigabit Ethernet**, **5 V** power input (their docs specify **5 V / 2.5 A** class supply for the board). **RTC** and fan header are on-board; the CM4 itself is not included.

Diagnostics-relevant notes:

- **PCIe Wi‑Fi (`mt7915e`)** rides the **M.2 M-key** link documented for that slot — same **power, mechanical, and thermal** caveats as any M.2 NIC on a small 5 V carrier (reseating, **adequate PSU**, **cold** power cycle if the link wedges).
- **Onboard CM4 Wi‑Fi / BT** use the **CM4’s own** u.FL / antenna arrangement, not the M.2 slot. Waveshare’s kit photos note **antennas are not included**; with **CM4108032** you still need **proper 2.4/5 GHz (and BT if split) antennas** connected per the CM4 mechanical setup, or performance may be poor and bring-up can look “dead.”
- **M.2 vs NVMe:** If the slot is populated with a **Wi‑Fi module**, it is **not** available for NVMe at the same time — only one M-key device.

### M.2 Wi‑Fi module (524WiFi AW7916-AED)

Mesh nodes here use **[524WiFi AW7916-AED](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/)** (**MediaTek MT7916AN**), marketed as **Wi‑Fi 6E AX3000**, **DBDC** (2.4 GHz + 5/6 GHz), **two IPEX antenna ports**, **PCIe 2.1** device. Vendor documentation points at the **Linux `mt76` / `mt7915e`** stack ([OpenWrt `mt7915` tree reference](https://github.com/openwrt/mt76/tree/master/mt7915) as cited on their product page).

**Power (from vendor spec):** up to **~8 W** peak, **~5 W** typical; they ask board designers for **3.3 V @ 3.5 A** (minimum **3 A**) to the module. On CM4 + IO boards, kernel logs often show **PCIe 3.3 V regulators as “dummy”** — if the **M.2 3.3 V rail sags** under this load (especially with **USB, CM4, and second radio**), expect **probe timeouts (-110)**, **ENOMEM (-12)**-style failures, or **intermittent** `mt7915e` bring-up. **Heatsink** (vendor ships **30×30×10 mm** option) matters for sustained power.

**M.2 keying:** The listing specifies **M.2 A+E key** (typical laptop Wi‑Fi). The [Waveshare CM4-IO-BASE-B](https://www.waveshare.com/cm4-io-base-b.htm) documents an **M key** slot — only use combinations that are **electrically and mechanically valid** (correct adapter, correct module variant, or a carrier that matches the module key).

**M.2 adapter (A+E → M-key socket):** Field build uses this **AliExpress** board: [item `4000175123887`](https://www.aliexpress.com/item/4000175123887.html?spm=a2g0o.order_list.order_list_main.66.787318027rHYJu) (confirm pinout/keying on the seller page). Adapters like this are a common way to fit **laptop-style Wi‑Fi modules** into **M-key PCIe** slots; quality varies — **3.3 V path, ground return, and connector wear** can contribute to **intermittent `mt7915e` probe (-110 / -12)** even when the **AW7916-AED** module itself is fine. Reseat adapter **and** module, and compare with a **known-good direct-fit** setup if problems persist.

**PCI ID on bench images:** `lspci` has shown **`14c3:7906`** with driver **`mt7915e`** — treat as **MediaTek Filogic / mt76 family**; marketing “7916” vs PCI **7906** naming can differ by stepping/SKU.

## Access

- SSH user: **`radio`** (root SSH was denied in our tests — likely disabled).
- Non-interactive SSH: **`iw`** and **`rfkill`** live under `/usr/sbin`. Use  
  `export PATH="/usr/sbin:/sbin:$PATH"`  
  or call `/usr/sbin/iw` explicitly.
- Prefer **`ssh -T`** (no TTY) if your client errors on pseudo-terminal allocation.

### One-shot diagnostics (canonical)

Use **[`mesh-node-diagnostics.sh`](mesh-node-diagnostics.sh)** — single script that consolidates what we use in bench sessions: **identity / `cmdline` + `pci=nomsi` / `config.txt` hints / `iw` + `ip` / PCIe / `lsmod` / `dmesg` (mt7915e, IRQ 26, AER, SDIO, Morse) / previous-boot kernel journal / unclean-shutdown markers / `systemctl --failed` / `vcgencmd` / `modinfo` firmware**.

**On the node** (copy script to the Pi, or mount the repo):

```bash
bash mesh-node-diagnostics.sh | tee ~/diag-$(date +%Y%m%d%H%M).txt
```

**From your dev machine** (repo root, replace host):

```bash
ssh -T radio@mesh-582a.local 'bash -s' < docs/mesh-node-diagnostics.sh | tee diag-$(date +%Y%m%d%H%M).txt
```

Use the **IP** instead of `.local` if mDNS is unreliable. Redirect **`tee`** to keep a dated capture after outages.

## Provisioning logs (typical locations)

| Path | Notes |
|------|--------|
| `/boot/firmware/firstrun.log` | First-boot script: user `radio`, SSH, `mesh-provision`, cleanup. |
| `/boot/firmware/provision.log` | Main provisioning (not `provison.log` — common typo). |
| `/var/log/radio-setup.log` | Post-boot radio / interface setup (mesh/AP selection). |

**Observed once:** firstrun and main provisioning completed (`Provisioning complete …`, `mesh-provision` disabled, reboot). Minor non-fatal noise: `dhcpcd` unit missing; optional `10-end1.network` copy failed if file absent on image.

**radio-setup:** Requires wireless PHYs. If **`iw dev`** shows no interfaces, setup can end with **no mesh/AP interfaces** and errors like **“No suitable interface found for AP”** when `eud=wireless`.

## How to check Wi‑Fi radios (optional extras)

Prefer **[`mesh-node-diagnostics.sh`](mesh-node-diagnostics.sh)** above. For spot checks:

```bash
export PATH="/usr/sbin:/sbin:$PATH"
iw dev
iw phy
rfkill list
iw reg get
lsusb
```

## Verifying onboard CM4 Wi‑Fi / Bluetooth are disabled

**CM4 (this project)** uses the standard Raspberry Pi firmware overlays **`dtoverlay=disable-wifi`** and, when you want Bluetooth off too, **`dtoverlay=disable-bt`**. They live in **`/boot/firmware/config.txt`** (Bookworm-era layout).

**Important:** Put **`dtoverlay=disable-bt`** under the **`[cm4]`** section. Entries under **`[pi4]`** / **`[pi3]`** / **`[pi0w]`** do **not** apply to a Compute Module 4 — a common mistake is **`hci0`** still appearing after reboot because **`disable-bt`** was only set for other Pi models.

A [Home Assistant community thread](https://community.home-assistant.io/t/disabling-built-in-wi-fi-bluetooth-from-raspberry-pi-cm4-on-home-assistant-yellow/644312) discusses disabling SDIO radios; **[post 11](https://community.home-assistant.io/t/disabling-built-in-wi-fi-bluetooth-from-raspberry-pi-cm4-on-home-assistant-yellow/644312/11)** is about **Raspberry Pi 5**, which needs different overlay names (**`disable-wifi-pi5`** / **`disable-bt-pi5`**) and sometimes **manually adding** `.dtbo` files. **Do not** mix Pi 5 overlay names into a **CM4** `config.txt` unless you are actually on a Pi 5.

### What “disabled” should look like

| Check | Onboard Wi‑Fi disabled | Onboard BT disabled |
|--------|-------------------------|----------------------|
| **Firmware** | `grep -E 'disable-wifi' /boot/firmware/config.txt` shows **`dtoverlay=disable-wifi`** (not commented) | Same for **`dtoverlay=disable-bt`** |
| **Driver** | **`brcmfmac`** does **not** appear in **`lsmod`** (SDIO WLAN block not brought up) | No **Bluetooth HCI** device; **`/sys/class/bluetooth`** empty or missing |
| **Runtime** | No **Broadcom SDIO `wlan*`** from **`iw dev`** / **`iw phy`** (only your **M.2** PHYs appear) | **`rfkill list`** has no Bluetooth controller, or **`hciconfig`** / **`bluetoothctl list`** show nothing (tools may be absent on minimal images) |
| **`dmesg`** | No successful **`brcmfmac`** / **CYW43455** attach; **`mmc1`** may still log on some builds — interpret together with **`disable-wifi`** | No **`hci0`** registration from the SDIO/BT side |

**[`mesh-node-diagnostics.sh`](mesh-node-diagnostics.sh)** prints **`config.txt` lines** (including **`disable-bt`**), **`lsmod`** for **`brcmf`**, short **`dmesg`** hints, **`rfkill`**, and Bluetooth sysfs so you can confirm in one capture.

### Quick manual check

```bash
grep -nE 'disable-wifi|disable-bt' /boot/firmware/config.txt
lsmod | grep -E '^brcmf' || echo "no brcmfmac loaded"
iw dev
ls /sys/class/bluetooth 2>/dev/null || echo "no Bluetooth class devices"
rfkill list 2>/dev/null
```

If **`disable-wifi`** is set but you still see **`brcmfmac`** and an SDIO **`wlan`**, the overlay is not active (wrong partition, typo, or **`config.txt`** not read — e.g. empty file).

## Lowering M.2 Wi‑Fi power (`mt7915e` / AW7916)

The **main knob you control in software** is **transmit power**. The driver/firmware still burns **baseline current** for PCIe, baseband, and the second DBDC chain; **vendor peak (~8 W)** is mostly **PA + processing under load**, not something you eliminate entirely without turning the interface off.

### What works

- **Cap TX power per interface** with **`iw`** (values are **mBm**; **100 mBm ≈ 1 dBm**). Example: **`500` ≈ 5 dBm** — same order as **`ap-txpower.service`** in [`radio-setup.sh`](../MANET/node_tools/radio-setup.sh), which applies to the **EUD AP** interface when that path is enabled. **Mesh backhaul (`wlan0` or whatever carries the mesh point)** is **not** covered by that unit; set it explicitly if you want a lower mesh TX level:

  ```bash
  export PATH="/usr/sbin:/sbin:$PATH"
  iw dev wlan0 info                    # confirm name / type
  iw phy "$(iw dev wlan0 info | awk '/wiphy/ {print "phy" $2}')" info | grep -i -E 'txpower|power|MHz'
  iw dev wlan0 set txpower fixed 500   # tune; stay within regulatory + phy max
  ```

  Use **`iw dev wlan0 set txpower auto`** to let the stack choose again. **`iw reg get`** and **`iw phy … info`** show what the kernel will allow.

- **Keep unused logical interfaces down** (e.g. **`ip link set wlan1 down`**) if you do not need the second band as AP/client — savings are **modest** on DBDC silicon (one package), but it avoids accidental traffic on that path.

- **Narrow channel / lower PHY rates** (e.g. **20 MHz** mesh, or tools like **legacy bitrate limits** in limp / tourguide scripts) can **reduce average airtime and power** at the cost of throughput; this is workload-specific.

### What to avoid on mesh backhaul

- **Do not enable 802.11 station power save** (**`iw dev … set power_save on`**) on interfaces used as **mesh points / BATMAN hops**. You need predictable availability to peers; client-style power save is the wrong model and can **hurt mesh stability** even when it appears to apply.

### What is not really tunable from userspace

- **`mt7915e`** exposes **few module parameters** on typical kernels (often **no** simple “low power mode” switch). **PCIe ASPM** is frequently **disabled or constrained** in the driver for stability — do not expect large savings from ASPM tweaks without driver/board work.

- **Firmware** and **internal calibration** dominate behavior below the TX cap; **heatsinking** and a **solid 3.3 V path** to the M.2 module affect **sustained** power and **reliability** more than a small mBm tweak.

### Making TX caps persistent

After you pick values that **still close the mesh**, mirror the existing **`ap-txpower.service`** pattern: **oneshot** **`iw dev <iface> set txpower fixed …`**, **`After=`** / **`BindsTo=`** the right **`sys-subsystem-net-devices-<iface>.device`**, enable the unit. Order it **after** whatever unit brings the interface to **mesh point** type, or use a small **ExecStartPre** delay / script that waits until **`iw dev`** shows the mesh iface — otherwise **`iw`** may run too early.

## What we saw on the reference unit (Wi‑Fi)

| Component | Observation |
|-----------|----------------|
| **PCIe Wi‑Fi** | Module: **[524WiFi AW7916-AED](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/)** (MT7916AN). `lspci`: **14c3:7906**, driver **`mt7915e`**. Observed failures: **`Message 000101ed` timeout → -110**, or **probe -12 (ENOMEM)** on some boots — power / DMA / thermal / firmware. |
| **Built-in Wi‑Fi** | **No `brcmfmac`** / no SDIO **`wlan*`** is **expected** if **`dtoverlay=disable-wifi`** (M.2-only bench profile). If onboard Wi‑Fi **is** enabled and still missing on **CM4108032**, treat as **SDIO / DT / antenna / carrier** — not a wireless-less SKU mistake. |
| **Morse HaLow** | Driver may log SPI probe failures; **ignore for bench diagnosis** when no HaLow hardware is connected (see above). |

### Bench update: U.FL / IPEX antenna (CM4108032 — onboard Wi‑Fi only)

**Applies only when onboard SDIO Wi‑Fi is enabled** (no `disable-wifi`). Skip if you use **M.2-only** mesh.

**What changed:** The CM4 wireless SKU exposes a small **U.FL** connector (often labeled **IPEX** / **IPX**). Kits like the [Waveshare CM4-IO-BASE-B](https://www.waveshare.com/cm4-io-base-b.htm) typically **do not ship** an antenna. With **no antenna** (or a wrong-band stub), the CYW43455 path can show as **no usable `wlan`**, flaky **SDIO/`mmc1`**, or **very weak** link — not necessarily a dead module. **Fitting a proper dual-band 2.4/5 GHz antenna** on that connector is required for normal RF.

**Firmware alignment:** The CM4 selects **internal PCB vs external U.FL** at boot via `config.txt` (**`dtparam=ant1`** vs **`dtparam=ant2`**); see the [CM4 datasheet §2.1](https://pip-assets.raspberrypi.com/categories/634-raspberry-pi-compute-module-4/documents/RP-008168-DS-2-cm4-datasheet.pdf). If you **only** use the pigtail antenna, prefer **`ant2`** so the RF switch matches the hardware.

**Confirm “up” isn’t cosmetic:**

```bash
export PATH="/usr/sbin:/sbin:$PATH"
iw dev
iw phy phy0 info 2>/dev/null | head -20   # adjust phy# if needed
ip -br link | grep wlan
sudo iw dev wlan0 scan | head -40         # APs visible = RX path plausible
```

Check **`/boot/firmware/config.txt`** (or overlay snippets) for **`ant1`/`ant2`**. PCIe **M.2** Wi‑Fi (`mt7915e`) remains a **separate** interface if present — use **`iw dev`** and **`lspci`** to see **both** radios.

## Hardware isolation (do this before blaming mesh scripts)

Treat **three independent paths**; only one needs to work for a useful bench node, but you must know **which** you have.

| Path | What “good” looks like | Typical failure |
|------|-------------------------|-----------------|
| **Onboard CM4 wireless** | `brcmfmac` loaded, `mmc1` brings up SDIO, `wlan0` (or similar) from Broadcom | **`disable-wifi` set** → path intentionally off; ignore. On **wireless-less** CM4 SKUs, `mmc1` failure is often **expected**. On **CM4108032** with onboard Wi‑Fi **enabled**, **`mmc1` failure + no `brcmfmac` is a bug to fix** (hardware, antenna, DT). |
| **PCIe NIC (AW7916-AED / 14c3:7906 / `mt7915e`)** | `lspci` sees device, `dmesg` completes probe, **`iw dev`** shows an interface | **-110** / **-12**: NIC, **M.2 3.3 V current**, slot, thermal, firmware — see [524WiFi AW7916-AED](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/) power notes |
| **Morse HaLow** | Only relevant if the module is wired; **-61 on SPI** with no hardware is noise | — |

### What the local `kernel-log-snapshot.txt` actually shows

That file is a **slice** of one boot (see `.gitignore` — optional local copy). On **mesh-582a** it includes:

- **PCIe**: `brcm-pcie … link up, 5.0 GT/s PCIe x1`; device **`[14c3:7906]`** enumerated — the **physical link and enumeration are OK** on that boot.
- **`mt7915e`**: Driver enables the device, disables ASPM, prints HW/SW and WM/WA firmware lines — then the **saved log ends** (Ethernet link-up). It does **not** include a later **-110** or `wlan` registration, so it **neither proves the NIC good nor bad**; you need **`journalctl -k -b 0` / `dmesg` through the full `mt7915e` probe**.

If firmware lines look like placeholders (`____000000` / `DEV_000000`), still read the **next** kernel lines: either **`wlan` appears** (likely fine) or **timeout / probe failed** (focus on NIC + power + firmware).

- **`mmc1: Failed to initialize a non-removable card`**: With **`disable-wifi`**, ignore for mesh (onboard path disabled). Otherwise on **CM4108032**, pair with **`brcmfmac`** / **`dmesg | grep -i brcmf`** — onboard Wi‑Fi block did not come up; fix **SDIO / antenna / DT** if you need that radio.

### Bench order (fastest discrimination)

1. **CM4 SKU / onboard radio** — **CM4108032** includes SDIO Wi‑Fi hardware; with **`disable-wifi`**, ignore SDIO for mesh. If your module is **without** wireless, `mmc1` / no internal `wlan` can be **expected**, and **PCIe or USB** must supply Wi‑Fi.
2. **PCIe mechanical / power** — Reseat the M.2 (or adapter), **cold** power-off 30s, try another **carrier** if available. Undersized PSU can show as **link drops** or **probe timeouts** under load (see [`network-drops-60s.md`](network-drops-60s.md)).
3. **Swap the NIC** — Same 7906-class module in **another** Linux host vs **another** known-good PCIe Wi‑Fi card in this CM4 isolates **module vs slot vs CM4**.
4. **Software contrast (one boot)** — Boot a **plain Raspberry Pi OS** (same kernel family if possible) and capture **`dmesg | grep -iE 'mt79|7915|7906|pcie'`**. If **Pi OS works** but the mesh image fails, suspect **firmware blobs, module blacklist, or init timing**; if **both fail**, weight **hardware / power** higher.
5. **Full failure capture** — Save complete probe output:  
   `dmesg -T > /tmp/dmesg.txt` immediately after boot (or persistent journal and `journalctl -k -b -1` after a failed boot).

### Useful follow-ups when PCIe Wi‑Fi times out (-110)

- Reseat module, cold power cycle, carrier-specific PCIe **3.3 V / enable / reset** notes.
- `dmesg | grep -E 'mt7915|7915|7906'` and compare loaded firmware files (`modinfo mt7915e`) to what the vendor/kernel expects.
- **`pci=nomsi`** on the kernel command line (`/boot/firmware/cmdline.txt`): [CM4 datasheet §2.3](https://pip-assets.raspberrypi.com/categories/634-raspberry-pi-compute-module-4/documents/RP-008168-DS-2-cm4-datasheet.pdf) notes this when PCIe devices misbehave on **MSI**; try if you see **`mt7915e` timeouts** together with IRQ issues below.
- **Security:** provisioning logs may contain mesh/AP keys — rotate if logs are shared.

### PCIe IRQ #26 / AER vs `mt7915e` probe (-110)

On a **bad** boot, `dmesg` can show **`irq 26: nobody cared`** on **CM4**, with handlers listed as **`pcie_pme_irq`** and **`aer_irq`** (PCIe **Advanced Error Reporting** on the root port), followed by **`Disabling IRQ #26`**. That line is shared with the **M.2** device under the BCM2711 bridge — once the kernel **disables** it, **`mt7915e` firmware messaging** often **times out** (`Message 000101ed …`, **-110**). **Bluetooth** (`hci0`) may also log **-110** in the same window.

**Mitigations to try (in order):** (1) **`pci=nomsi`** in `cmdline.txt` and reboot; (2) **`irqpoll`** on the command line for a **diagnostic** boot only (high overhead — confirms spurious/unhandled IRQ theory); (3) **hardware**: cold cycle, **M.2 + adapter reseat**, **PSU / 3.3 V** margin per [AW7916-AED](https://524wifi.net/product/524wifi-wifi6e-3000-802-11ax-g-band-2t2r-a-band-3t3r-2ss-dual-bands-dual-concurrent-dbdc-m-2-aw7916-aed-mediatek-mt7916an-524wifi/) notes.

**Unclean shutdown:** journal files may log **corrupted or uncleanly shut down** after watchdog or power loss — use persistent journal + `journalctl -k -b -1` when available (see below).

## Kernel log snapshot (grabbed from device)

- **`kernel-log-snapshot.txt`** — optional **local** copy of `journalctl -k -b 0` (gitignored by default). Regenerate after incidents; keep a **full** capture when isolating **-110** (see above).

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

## Capturing reset cause — phased plan (UART + optional ramoops)

When the node **disappears** (watchdog, hang, power glitch), **SSH and disk logs often have nothing useful** from the last second. A **USB‑UART (3.3 V TTL)** on the CM4’s **primary UART** is the usual way to get a **smoking gun** (panic string, last `dmesg` line, or total silence before reset).

### Phase 0 — Hardware (before first power-on with UART)

- **Adapter:** **3.3 V** USB‑TTL (FTDI / CP2102 / CH340, etc.). **Do not** use 5 V UART on Pi GPIO.
- **Wiring:** **GND ↔ GND**. **Pi TX → adapter RX** (often **GPIO 14** / **TXD0**). **Pi RX ← adapter TX** (often **GPIO 15** / **RXD0**). Confirm **pinout** for your **carrier** ([Waveshare CM4-IO-BASE-B](https://www.waveshare.com/cm4-io-base-b.htm) maps these on the **40‑pin** header).
- **Baud:** **115200 8N1** (matches typical `cmdline` **`console=serial0,115200`**).
- **Safety:** Connect UART **before** power; avoid shorts. If the board **boots** with UART disconnected, you can attach **GND + TX** only first to **read** (one-way log) with less risk of wiring TX/RX wrong.

### Phase 1 — Host PC: capture a full session

1. Find the device: **`ls /dev/ttyUSB*`** or **`/dev/tty.usbserial-*`** (macOS).
2. Open a terminal and **log everything** to a file. Examples: **`screen -L -Logfile ~/cm4-serial.log /dev/ttyUSB0 115200`** (adjust device path), or **minicom** with **capture** on, or **`sudo cat /dev/ttyUSB0`** after **`stty -F /dev/ttyUSB0 115200`** piped to **`tee ~/cm4-serial-$(date +%Y%m%d-%H%M).log`**.
3. **Power the CM4** (or reset). You should see **bootloader / Linux** text immediately. If the screen is **blank**, swap **TX/RX** once (power off first), or check **GND** and **wrong voltage**.
4. **Reproduce** the failure (mesh load, stress, wait for drop). **Do not** rely on SSH still working — the serial line is independent.

### Phase 2 — What to look for in the log (“smoking gun” patterns)

| Pattern | Likely meaning |
|--------|----------------|
| **`Kernel panic`**, **`Oops`**, **`BUG:`** | Software/driver fault; note the **stack trace** and module name (`mt7915e`, `batman_adv`, …). |
| **Freeze** — log stops mid-line, then **reboot** with no panic | **Hard hang**, **power loss**, or **watchdog reset** without a clean panic path. |
| **`watchdog`**, **`Watchdog did not stop`**, **`watchdog0`** | Interaction with **hardware watchdog**; pair with [`network-drops-60s.md`](network-drops-60s.md). |
| **`mt7915e`**, **`timeout`**, **`-110`**, **`AER`**, **`irq`** | PCIe / NIC path; compare with **`pci=nomsi`** and power notes elsewhere in this doc. |
| **Nothing** on serial, but **PWR LED** dies | **Supply** or **board** — use **inline USB meter** / different PSU, not more kernel flags. |

Save the **raw `.log`**; it is evidence for forums / upstream.

### Phase 3 — Optional: `ramoops` + `pstore` (panic survives reboot)

If you get **panics** but serial was not connected, **ramoops** can store the **oops/panic** in a **reserved RAM** region and expose it after reboot under **`/sys/fs/pstore/`**. This requires **consistent `cmdline` + DT memory reservation** — treat as **advanced**; validate on a **spare** image. Search **“Linux ramoops raspberry pi”** for current examples matching your kernel.

### Phase 4 — Debug-only watchdog relaxation

To prove **“hang then WDT reset”** vs **“instant power loss”**, see **Mitigation A** in [`network-drops-60s.md`](network-drops-60s.md) (**disable systemd hardware watchdog** temporarily). **Only** with **serial** attached — otherwise a hang leaves a **brick** with no network.

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

## Network dies after ~1 minute

See **[`network-drops-60s.md`](network-drops-60s.md)** — hardware watchdog vs PCIe Wi‑Fi vs empty mesh configs.

## Related repo paths

- Provisioning scripts/docs: `MANET/provisioning/`
