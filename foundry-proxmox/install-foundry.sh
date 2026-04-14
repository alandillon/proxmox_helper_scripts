#!/usr/bin/env bash
set -euo pipefail

APP_USER="foundry"
APP_DIR="/opt/foundryvtt"
DATA_DIR="/opt/foundrydata"
SERVICE_NAME="foundryvtt"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    exit 1
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt upgrade -y
  apt install -y curl wget unzip ca-certificates gnupg lsb-release
}

install_node() {
  if command -v node >/dev/null 2>&1; then
    echo "Existing Node version: $(node -v)"
  fi

  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt install -y nodejs

  echo "Installed Node version: $(node -v)"
  echo "Installed npm version: $(npm -v)"
}

create_user_and_dirs() {
  if ! id "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin "${APP_USER}"
  fi

  mkdir -p "${APP_DIR}" "${DATA_DIR}"
  chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}" "${DATA_DIR}"
}

download_foundry() {
  echo
  echo "Paste your Foundry Node.js timed URL."
  echo "Get it from your Foundry account Downloads page."
  echo "It expires quickly, so copy it right before pasting."
  read -r -p "Timed URL: " FOUNDRY_URL

  if [[ -z "${FOUNDRY_URL}" ]]; then
    echo "No download URL supplied."
    exit 1
  fi

  su -s /bin/bash -c "cd '${APP_DIR}' && wget -O foundryvtt.zip \"${FOUNDRY_URL}\"" "${APP_USER}"
  su -s /bin/bash -c "cd '${APP_DIR}' && unzip -o foundryvtt.zip && rm -f foundryvtt.zip" "${APP_USER}"

  if [[ ! -f "${APP_DIR}/main.js" ]]; then
    echo "Foundry install failed: main.js not found."
    echo "Make sure you used the Node.js build, not the desktop build."
    exit 1
  fi
}

create_service() {
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Foundry Virtual Tabletop
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/node ${APP_DIR}/main.js --dataPath=${DATA_DIR}
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}"
}

show_result() {
  echo
  echo "Install complete."
  echo "Service: ${SERVICE_NAME}"
  echo "App dir: ${APP_DIR}"
  echo "Data dir: ${DATA_DIR}"
  echo
  echo "Check status:"
  echo "  systemctl status ${SERVICE_NAME}"
  echo
  echo "Logs:"
  echo "  journalctl -u ${SERVICE_NAME} -f"
  echo
  echo "Open in browser:"
  echo "  http://<container-ip>:30000"
}

main() {
  require_root
  install_packages
  install_node
  create_user_and_dirs
  download_foundry
  create_service
  show_result
}

main "$@"
