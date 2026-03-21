#!/usr/bin/env bash
# Run ON the Pi after enabling dtoverlay=ramoops — checks pstore / ramoops / systemd-pstore.
set +e
echo "=== dmesg (ramoops / pstore) ==="
dmesg 2>/dev/null | grep -iE 'ramoops|pstore' || echo "(no ramoops/pstore lines — overlay may be missing or disabled)"

echo "=== /sys/fs/pstore ==="
if mountpoint -q /sys/fs/pstore 2>/dev/null; then
  ls -la /sys/fs/pstore
else
  echo "(pstore not mounted)"
fi

echo "=== systemd-pstore (Raspberry Pi OS) ==="
systemctl is-enabled systemd-pstore.service 2>/dev/null || true
systemctl status systemd-pstore.service --no-pager 2>/dev/null | head -12 || true

echo "=== /var/lib/systemd/pstore (archived oops, if any) ==="
ls -la /var/lib/systemd/pstore 2>/dev/null | head -20 || echo "(none or path missing)"

echo "=== kernel config (if readable) ==="
zcat /proc/config.gz 2>/dev/null | grep -E '^CONFIG_PSTORE' | head -15 || echo "(no /proc/config.gz)"

echo "=== done ==="
