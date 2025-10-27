# Despliegue en VPS para exponer la UI de Proxmox a Internet

Objetivo: poner un VPS público que se conecte a la VPN usando `client.ovpn` y `cacert.pem`, y que actúe como reverse-proxy público hacia la IP interna `172.22.0.11:8006` (Proxmox).

IMPORTANTE: este repositorio NO almacena credenciales. Debes copiar `client.ovpn`, `cacert.pem` y crear un fichero `auth.txt` con tus credenciales en el VPS con permisos restringidos.

Requisitos del VPS
- Ubuntu 20.04/22.04 o Debian reciente
- Acceso SSH con sudo
- Puerto 80/443 abiertos (si quieres HTTPS) o un puerto público si no tienes dominio

Archivos en este directorio
- `setup-vps.sh` — script que instala OpenVPN y Nginx, y despliega la configuración (plantilla). No contiene credenciales.
- `proxmox-nginx.conf` — plantilla de configuración de Nginx para proxy reverso.

Flujo recomendado
1. Sube `client.ovpn` y `cacert.pem` al VPS en `/etc/openvpn/client/`.
2. Crea `/etc/openvpn/client/auth.txt` con dos líneas: usuario\ncontraseña. Protege el archivo: `chmod 600` y ownership a root.
3. Ejecuta `sudo bash setup-vps.sh` en el VPS.
4. Revisa los logs de OpenVPN (`journalctl -u openvpn-client@client.service -f`) y verifica conectividad hacia `172.22.0.11:8006` desde el VPS.
5. Si tienes dominio, configura DNS apuntando al IP del VPS y considera usar Certbot para Let’s Encrypt (no automatizado en este script). Si no tienes dominio, Nginx puede escuchar en un puerto público y proxyar sin TLS; no es recomendado para producción.

Seguridad y notas
- No subas `auth.txt` ni `client.ovpn` con credenciales al repositorio.
- Si Proxmox usa HTTPS con certificado autofirmado, Nginx desactivará la verificación SSL hacia el upstream para poder proxear.
- Para mayor seguridad, restringe acceso por IP, añade autenticación básica en Nginx, o usa un túnel TLS con un dominio y Let's Encrypt.

Si quieres, puedo generar también un unit systemd para ejecutar un script de reconexión/monitorización, o añadir pasos para habilitar HTTPS automático con certbot si me das un dominio.
