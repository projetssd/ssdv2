#!/bin/sh
# Ensure the ssdv2ctl wrapper is available in the user's ~/.local/bin.
# Idempotent and best-effort: it must never break profile.sh or seedbox.sh.

set -u

target_home="${HOME:-}"
source_dir="${SETTINGS_SOURCE:-${target_home}/seedbox-compose}"
owner="${OWNER:-}"

[ -n "$target_home" ] || exit 0
[ -f "$source_dir/ssdv2ctl" ] || exit 0

bin_dir="${target_home}/.local/bin"
wrapper="${bin_dir}/ssdv2ctl"
marker="# SSDV2 ssdv2ctl wrapper (generated)"

python_bin="${source_dir}/venv/bin/python3"
[ -x "$python_bin" ] || python_bin="${source_dir}/venv/bin/python"
if [ ! -x "$python_bin" ]; then
    python_bin="$(command -v python3 2>/dev/null || true)"
fi
[ -n "$python_bin" ] || exit 0

if [ ! -d "$bin_dir" ]; then
    mkdir -p "$bin_dir" 2>/dev/null || exit 0
fi

# Keep a user-managed wrapper untouched.
if [ -f "$wrapper" ] && [ -x "$wrapper" ]; then
    if ! grep -qF "$marker" "$wrapper" 2>/dev/null; then
        exit 0
    fi
    if grep -qF "exec \"$python_bin\" \"$source_dir/ssdv2ctl\"" "$wrapper" 2>/dev/null; then
        exit 0
    fi
fi

tmp="${wrapper}.tmp.$$"
{
    printf '%s\n' '#!/bin/sh'
    printf '%s\n' "$marker"
    printf 'exec "%s" "%s" "$@"\n' "$python_bin" "$source_dir/ssdv2ctl"
} > "$tmp" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null
    exit 0
}
chmod 0755 "$tmp" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null
    exit 0
}
mv -f "$tmp" "$wrapper" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null
    exit 0
}

if [ "$(id -u)" -eq 0 ] && [ -n "$owner" ]; then
    chown "$owner" "$wrapper" 2>/dev/null || true
    chown "$owner" "$bin_dir" 2>/dev/null || true
fi

exit 0
