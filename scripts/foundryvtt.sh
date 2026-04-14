#!/usr/bin/env bash
set -Ee -o pipefail

export SSH_CLIENT="${SSH_CLIENT-}"
export SSH_TTY="${SSH_TTY-}"
export TERM="${TERM:-xterm}"

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="FoundryVTT"
var_tags="${var_tags:-gaming;vtt;foundry}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-12}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

update_script() {
  header_info "$APP"
  if [[ -z "${CTID:-}" ]]; then
    msg_error "No CTID selected"
    exit 1
  fi

  if ! pct status "$CTID" >/dev/null 2>&1; then
    msg_error "Container $CTID not found"
    exit 1
  fi

  msg_info "Re-running FoundryVTT installer in CT $CTID"
  pct start "$CTID" >/dev/null 2>&1 || true
  pct exec "$CTID" -- bash -lc 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/alandillon/proxmox-helper-scripts/main/install/foundryvtt-install.sh)"'
  msg_ok "Updated Successfully"

  IP="$(pct exec "$CTID" -- hostname -I | awk "{print \$1}")"
  if [[ -n "${IP}" ]]; then
    echo " FoundryVTT should be reachable at: http://${IP}:30000"
  fi
  exit 0
}

start
build_container

msg_info "Running FoundryVTT installer inside the container"
pct exec "$CTID" -- bash -lc 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/alandillon/proxmox-helper-scripts/main/install/foundryvtt-install.sh)"'
msg_ok "Completed Successfully"

IP="$(pct exec "$CTID" -- hostname -I | awk '{print $1}')"
if [[ -n "${IP}" ]]; then
  echo " FoundryVTT should be reachable at: http://${IP}:30000"
fi
