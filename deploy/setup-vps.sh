#!/usr/bin/env bash
set -euo pipefail

# setup-vps.sh
# Script para ejecutar en un VPS Ubuntu/Debian con acceso sudo.
# No coloca credenciales en el repositorio: debes copiar `client.ovpn`, `cacert.pem`
# y `auth.txt` manualmente en /etc/openvpn/client/ antes de ejecutar.

OPENVPN_DIR=/etc/openvpn/client
NGINX_SITE=/etc/nginx/sites-available/proxmox.conf

echo "Corriendo setup en "+"$(hostname)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script requiere sudo/root. Ejecuta: sudo bash setup-vps.sh" >&2
  exit 1
fi

apt-get update
apt-get install -y openvpn nginx curl

mkdir -p ${OPENVPN_DIR}
chmod 700 ${OPENVPN_DIR}

echo "Comprobando que existan /etc/openvpn/client/client.ovpn y cacert.pem"
if [ ! -f "${OPENVPN_DIR}/client.ovpn" ]; then
  echo "ERROR: copia client.ovpn a ${OPENVPN_DIR}/client.ovpn y vuelve a ejecutar." >&2
  exit 1
fi
if [ ! -f "${OPENVPN_DIR}/cacert.pem" ]; then
  echo "WARNING: cacert.pem no encontrada en ${OPENVPN_DIR}. Sigue si tu .ovpn lo requiere." >&2
fi
if [ ! -f "${OPENVPN_DIR}/auth.txt" ]; then
  echo "ERROR: crea ${OPENVPN_DIR}/auth.txt (usuario\ncontraseña) y protege con chmod 600." >&2
  exit 1
fi

# Copiar el .ovpn a la ubicación que usará systemd: /etc/openvpn/client/client.conf
cp ${OPENVPN_DIR}/client.ovpn ${OPENVPN_DIR}/client.conf
chmod 600 ${OPENVPN_DIR}/client.conf
chown root:root ${OPENVPN_DIR}/client.conf

echo "Creando servicio systemd para openvpn-client@client"
cat > /etc/systemd/system/openvpn-client@.service <<'EOF'
[Unit]
Description=OpenVPN connection to %i
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/client/%i.conf --auth-user-pass /etc/openvpn/client/auth.txt
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now openvpn-client@client.service

echo "Configurando Nginx como proxy reverso (plantilla)"
cat > ${NGINX_SITE} <<'EOF'
server {
    listen 80;
    server_name _; # Reemplazar por tu dominio si lo tienes

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # upstream es la IP interna detrás de la VPN
        proxy_pass https://172.22.0.11:8006;

        # Si el upstream usa certificado autofirmado
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
    }
}
EOF

ln -sf ${NGINX_SITE} /etc/nginx/sites-enabled/proxmox.conf
nginx -t
systemctl restart nginx

echo "Setup completado. Revisa:
- systemctl status openvpn-client@client.service
- journalctl -u openvpn-client@client.service -f
- nginx configuration: ${NGINX_SITE}
"

echo "Si quieres HTTPS con dominio, instala certbot y configura el server_name en ${NGINX_SITE}."
