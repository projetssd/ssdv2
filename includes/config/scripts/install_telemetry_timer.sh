#!/usr/bin/env bash
# Configure la synchronisation SSDV2, non bloquante.
set -Eeuo pipefail

[ "$(id -u)" -eq 0 ] || exit 0
command -v systemctl >/dev/null 2>&1 || exit 0
owner="${SSDV2_OWNER:-${SUDO_USER:-}}"
[[ "$owner" =~ ^[a-z_][a-z0-9_-]{0,30}$ ]] || exit 0
home="$(getent passwd "$owner" | cut -d: -f6)"
[ -n "$home" ] && [ -d "$home" ] || exit 0
source_dir="${SETTINGS_SOURCE:-${home}/seedbox-compose}"
script="${source_dir}/includes/config/scripts/telemetry.py"
[ -f "$script" ] || exit 0

service_name="ssdv2-telemetry-${owner}"
service_path="/etc/systemd/system/${service_name}.service"
timer_path="/etc/systemd/system/${service_name}.timer"
cat >"$service_path" <<EOF
[Unit]
Description=SSDV2 community statistics
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
User=${owner}
Environment=HOME=${home}
Environment=SETTINGS_SOURCE=${source_dir}
ExecStart=/usr/bin/python3 "${script}" sync
TimeoutStartSec=25
NoNewPrivileges=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
EOF
cat >"$timer_path" <<EOF
[Unit]
Description=Daily SSDV2 statistics refresh

[Timer]
OnCalendar=daily
OnBootSec=15min
RandomizedDelaySec=3h
Persistent=true
Unit=${service_name}.service

[Install]
WantedBy=timers.target
EOF
chmod 0644 "$service_path" "$timer_path"
systemctl daemon-reload >/dev/null
systemctl enable --now "${service_name}.timer" >/dev/null
