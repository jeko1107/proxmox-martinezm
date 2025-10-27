#!/usr/bin/env bash
set -euo pipefail

# setup-tailscale-funnel.sh
#
# Script para ejecutar en un equipo dentro de la LAN que tenga conectividad a
# 172.22.0.11:8006. El script instalará Tailscale, conectará el nodo usando
# un auth key proporcionado y desplegará un proxy Nginx local que reenvíe
# tráfico hacia https://172.22.0.11:8006.
#
# IMPORTANTE:
# - Debes generar un auth key (ephemeral o reusable) en https://login.tailscale.com/admin/authkeys
#   y pasarlo al script con --authkey. No incluyas el auth key en repositorios públicos.
# - Habilitar Funnel para el dispositivo se hace desde la consola admin.tailscale.com
#   (Machines -> seleccionar dispositivo -> Enable Funnel). El script crea y deja
#   el proxy listo; la activación del Funnel requiere acceso a la cuenta Tailscale.

USAGE="\
Uso: sudo ./setup-tailscale-funnel.sh --authkey <tskey> [--hostname <name>] [--upstream <host:port>] [--local-port <port>]

Opciones:
  --authkey     (obligatorio) auth key generado en admin.tailscale.com
  --hostname    nombre para el dispositivo en el tailnet (default: proxmox-proxy)
  --upstream    destino interno al que proxear (default: 172.22.0.11:8006)
  --local-port  puerto local donde Nginx escuchará (default: 8006)
\n+Ejemplo:
  sudo ./setup-tailscale-funnel.sh --authkey tskey-xxxxx --hostname proxmox-proxy --upstream 172.22.0.11:8006
"

AUTHKEY=""
HOSTNAME="proxmox-proxy"
UPSTREAM="172.22.0.11:8006"
LOCAL_PORT="8006"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --authkey) AUTHKEY="$2"; shift 2;;
    --hostname) HOSTNAME="$2"; shift 2;;
    --upstream) UPSTREAM="$2"; shift 2;;
    --local-port) LOCAL_PORT="$2"; shift 2;;
    -h|--help) echo "$USAGE"; exit 0;;
    *) echo "Parámetro desconocido: $1" >&2; echo "$USAGE"; exit 1;;
  esac
done

if [ -z "$AUTHKEY" ]; then
  echo "ERROR: --authkey es obligatorio" >&2
  echo
  echo "$USAGE"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script requiere privilegios de root. Ejecuta: sudo $0 ..." >&2
  exit 1
fi

echo "Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "Arrancando Tailscale con el authkey (esto registrará el dispositivo en tu tailnet)..."
tailscale up --authkey "$AUTHKEY" --hostname "$HOSTNAME" || {
  echo "Error al ejecutar 'tailscale up'. Revisa el authkey y la conectividad." >&2
  exit 2
}

echo
echo "Instalando nginx..."
apt-get update
apt-get install -y nginx

NGINX_CONF=/etc/nginx/sites-available/tailscale-proxmox.conf
echo "Escribiendo configuración de Nginx en ${NGINX_CONF} (proxy a https://${UPSTREAM})"
cat > "$NGINX_CONF" <<EOF
server {
    listen 127.0.0.1:${LOCAL_PORT} ssl;
    server_name _;

    # SSL local auto-self-signed (no necesario si solo Funnel maneja TLS hacia Internet)
    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass https://${UPSTREAM};

        proxy_ssl_server_name on;
        proxy_ssl_verify off;

        proxy_read_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/tailscale-proxmox.conf

echo "Probando configuración de Nginx..."
nginx -t

echo "Reiniciando Nginx..."
systemctl restart nginx

echo
echo "LISTO: Tailscale y Nginx están instalados y corriendo. Resumen:" 
echo "  - Device hostname: $HOSTNAME"
echo "  - Upstream interno: $UPSTREAM"
echo "  - Nginx escucha en 127.0.0.1:${LOCAL_PORT} y hace proxy a https://${UPSTREAM}"

echo
echo "Pasos siguientes (desde tu cuenta Tailscale admin):"
cat <<'INFO'
1) Entra en https://login.tailscale.com/admin/machines y localiza el dispositivo con el hostname indicado.
2) Habilita Funnel para ese dispositivo (Options -> Enable Funnel). Selecciona el puerto público que quieras exponer (por ejemplo 443) y mapea al puerto local ${LOCAL_PORT}.
   - Si tu cuenta no muestra la opción Funnel, puede que necesites permisos o un plan que lo permita.
3) Tras habilitar Funnel, Tailscale te dará una URL pública y gestionará TLS.
4) Para comprobar el estado local del dispositivo:
   sudo tailscale status
   sudo tailscale ip -4

Notas de seguridad:
- Recomendado: restringir acceso en la consola de Tailscale (Access Controls) o añadir autenticación extra en Nginx si vas a exponer Proxmox al público.
- No dejes el auth key en archivos sin protección. Borra auth keys innecesarios desde admin.tailscale.com.

Si quieres, puedo añadir una sección opcional que use la Admin API para habilitar Funnel automáticamente si me proporcionas un API key de administrador (no recomendado dejarlo en el repo).
INFO

echo
echo "Comprobación rápida local: puedes hacer (desde este host):"
echo "  curl -vk --resolve 'localhost:${LOCAL_PORT}:127.0.0.1' https://localhost:${LOCAL_PORT}/"

exit 0
