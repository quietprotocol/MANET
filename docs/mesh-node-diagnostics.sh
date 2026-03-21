#!/usr/bin/env bash
# CM4 / MANET mesh node — one-shot field diagnostics (stdout only).
# Run ON the node:   bash mesh-node-diagnostics.sh | tee diag.txt
# Run FROM dev host: ssh -T radio@NODE 'bash -s' < docs/mesh-node-diagnostics.sh | tee diag.txt
#
# Covers: M.2 mt7915e, pci=nomsi, IRQ #26/AER, Morse/brcmf interference, boot/journal health.

set +e
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

echo "========== mesh-node-diagnostics $(date -u +%Y-%m-%dT%H:%M:%SZ) =========="
echo "=== identity ==="
hostname
uptime
echo -n "kernel: "; uname -r
echo -n "boot_id: "; cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo "n/a"

echo "=== boot cmdline (pci=nomsi?) ==="
cat /boot/firmware/cmdline.txt 2>/dev/null || echo "(no /boot/firmware/cmdline.txt)"

echo "=== config.txt (radio-related lines) ==="
grep -nE '^\[|disable-wifi|disable-bt|pcie-32bit|morse|mm610|spi=|camera|sdio' /boot/firmware/config.txt 2>/dev/null | head -40 || echo "(no config.txt)"

echo "=== onboard CM4 SDIO Wi-Fi / BT (disabled = no brcmf / no hci) ==="
lsmod 2>/dev/null | grep -E '^brcmf' || echo "(no brcmfmac — expected if disable-wifi)"
dmesg 2>/dev/null | grep -iE 'brcmf|cyw43455|Bluetooth hci' | tail -15 || true
if [ -d /sys/class/bluetooth ]; then
  ls -1 /sys/class/bluetooth 2>/dev/null || true
else
  echo "(no /sys/class/bluetooth — BT likely off or no driver)"
fi
rfkill list 2>/dev/null | head -25 || true

echo "=== wireless / bridge ==="
iw dev 2>/dev/null
echo "---"
ip -br link

echo "=== PCIe ==="
lspci -nn 2>/dev/null | grep -iE 'network|bridge|mediatek|14c3' || lspci -nn

echo "=== lsmod (mt79 / brcmf / morse) ==="
lsmod | grep -iE '^mt79|^mt76|^brcmf|^morse|^dot11' || echo "(none matched)"

echo "=== dmesg: PCIe + mt7915e + IRQ 26 + SDIO/Morse ==="
dmesg 2>/dev/null | grep -iE 'brcm-pcie|14c3:7906|mt7915|7915|7906|irq 26|nobody cared|Disabling IRQ|AER|aer_|Message 000101ed|probe.*fail|error -1[0-9]{2}|mmc1:|brcmf|morse_spi|dot11ah' | tail -80

echo "=== dmesg: watchdog / throttled (if any) ==="
dmesg 2>/dev/null | grep -iE 'watchdog|throttl|Under-voltage|oom-killer|Out of memory' | tail -20 || true

echo "=== journal: previous boot kernel (last lines) ==="
journalctl -k -b -1 --no-pager 2>/dev/null | tail -40
if ! journalctl -k -b -1 --no-pager 2>/dev/null | grep -q .; then
  echo "(no previous-boot kernel journal — enable persistent journal; see device-diagnostics-notes.md)"
fi

echo "=== journal: unclean / corrupt (this boot) ==="
journalctl -b 0 --no-pager 2>/dev/null | grep -iE 'corrupt|unclean|Dirty bit' | tail -15 || true

echo "=== systemd failed units ==="
systemctl --failed --no-pager 2>/dev/null | head -20

echo "=== vcgencmd ==="
command -v vcgencmd >/dev/null && vcgencmd get_throttled 2>/dev/null || echo "(no vcgencmd)"

echo "=== mt7915e firmware (needs readable module) ==="
modinfo mt7915e 2>/dev/null | grep -i firmware | head -8 || echo "(modinfo mt7915e failed)"

echo "========== end =========="
