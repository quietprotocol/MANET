#!/usr/bin/env bash
# Run ON the mesh node under normal or heavy load; save output before an expected crash.
# Usage:  bash pre-crash-snapshot.sh | tee ~/pre-crash-$(date +%Y%m%d-%H%M%S).txt
set +e
export PATH="/usr/sbin:/sbin:/usr/bin:/bin"

echo "========== pre-crash-snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ) =========="
echo "=== identity ==="
hostname
uptime
uname -r

echo "=== thermal / power ==="
command -v vcgencmd >/dev/null && { vcgencmd measure_temp; vcgencmd get_throttled; } || true

echo "=== memory / disk ==="
free -h
df -h / /boot/firmware 2>/dev/null | tail -5

echo "=== PCIe device + link (short) ==="
lspci -nn | grep -iE '14c3|mediatek|2711'
lspci -vv -s 01:00.0 2>/dev/null | grep -iE "LnkSta|DevSta|Control:|Status:|MSI|Interrupt"

echo "=== PCIe AER (counters; want zeros) ==="
if [ -d /sys/bus/pci/devices/0000:01:00.0 ]; then
  grep -h 'TOTAL_ERR' /sys/bus/pci/devices/0000:01:00.0/aer_dev_* 2>/dev/null || true
else
  echo "(no 0000:01:00.0 — check lspci bus address)"
fi

echo "=== ip -s link (errors/drops) ==="
for d in wlan0 wlan1 end0 bat0 br0; do
  ip -s link show dev "$d" 2>/dev/null && echo "---"
done

echo "=== batman originators (first 20 lines) ==="
command -v batctl >/dev/null && batctl o 2>/dev/null | head -20 || echo "(batctl missing or no mesh)"

echo "=== iw wlan0 (mesh) ==="
iw dev wlan0 info 2>/dev/null | head -15

echo "=== dmesg: mt7915 / pcie / aer / SError / panic / watchdog (tail) ==="
dmesg 2>/dev/null | grep -iE 'mt7915|7906|14c3:7906|pcie|aer|SError|panic|not syncing|watchdog|throttl|oom|Out of memory' | tail -40

echo "=== dmesg (last 25 lines, any) ==="
dmesg 2>/dev/null | tail -25

echo "========== end =========="
