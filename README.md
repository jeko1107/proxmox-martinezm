# Proxmox VM Starter

Este script permite encender múltiples máquinas virtuales en Proxmox de manera automatizada.

## Configuración

El script requiere dos variables de entorno:

### PROXMOX_IP
La dirección IP y puerto del servidor Proxmox (incluyendo el puerto).

**Ejemplo:**
```bash
export PROXMOX_IP="172.22.0.11:8006"
```

### PROXMOX_TOKEN
El token de autenticación de la API de Proxmox.

**Ejemplo:**
```bash
export PROXMOX_TOKEN="PVEAPIToken=1SMRA-jortmor1107@IESMM!encender=65a14e2a-a688-483a-8d4b-05f4681cbb55"
```

## Uso

1. Configura las variables de entorno:
```bash
export PROXMOX_IP="172.22.0.11:8006"
export PROXMOX_TOKEN="PVEAPIToken=1SMRA-jortmor1107@IESMM!encender=65a14e2a-a688-483a-8d4b-05f4681cbb55"
```

2. Ejecuta el script:
```bash
python3 start_vms_openvpn.py
```

## VMs Configuradas

El script encenderá las siguientes VMs:
- VM 1286 en nodo proxS4
- VM 1288 en nodo proxS3
- VM 1110 en nodo proxS3
- VM 1109 en nodo proxS7

## Requisitos

- Python 3
- Librería `requests` (instalar con `pip install requests`)
