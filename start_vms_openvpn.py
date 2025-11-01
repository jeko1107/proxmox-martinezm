#!/usr/bin/env python3
import subprocess
import time
import sys
import os
import requests
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

# === CONFIGURACIÓN ===
PROXMOX_IP = os.environ["PROXMOX_IP"]
TOKEN = os.environ["PROXMOX_TOKEN"]
API_URL = f"https://{PROXMOX_IP}:8006/api2/json"

VMS = {
    "1286": "proxS4",
    "1288": "proxS3",
    "1110": "proxS3",
    "1109": "proxS7",
}

def connect_vpn():
    print("Conectando a OpenVPN...")

    # Inicia OpenVPN en segundo plano con logs
    cmd = [
        "openvpn",
        "--config", "/tmp/instituto.ovpn",
        "--auth-user-pass", "/tmp/auth.txt",
        "--ca", "/tmp/cacert.pem",
        "--log", "/tmp/openvpn.log",  # <-- LOGS
        "--daemon"
    ]

    try:
        subprocess.run(cmd, check=False)
        print("OpenVPN iniciado. Esperando conexión...")
    except Exception as e:
        print(f"Error al iniciar OpenVPN: {e}")
        return False

    # Espera hasta 60 segundos por interfaz TUN/TAP
    for i in range(12):
        time.sleep(5)
        result = subprocess.run(["ip", "link", "show", "type", "tun"], capture_output=True, text=True)
        if "tun" in result.stdout or "tap" in result.stdout:
            print("Interfaz VPN detectada (tun/tap)")
            # Verifica ping
            ping = subprocess.run(["ping", "-c", "1", PROXMOX_IP], capture_output=True, timeout=5)
            if ping.returncode == 0:
                print("VPN conectada y Proxmox accesible")
                return True
        print(f"Intento {i+1}/12: VPN no lista aún...")

    print("ERROR: No se pudo conectar a la VPN en 60 segundos")
    print("Logs de OpenVPN:")
    try:
        with open("/tmp/openvpn.log", "r") as f:
            print(f.read())
    except:
        print("No se pudo leer el log")
    return False

def start_vm(vmid, node):
    url = f"{API_URL}/nodes/{node}/qemu/{vmid}/status/start"
    headers = {"Authorization": TOKEN}
    try:
        r = requests.post(url, headers=headers, verify=False, timeout=10)
        if r.status_code == 200:
            print(f"VM {vmid} encendida")
        else:
            print(f"Error {r.status_code}: {r.text}")
    except Exception as e:
        print(f"Error de red en VM {vmid}: {e}")

def main():
    if not connect_vpn():
        sys.exit(1)

    print("Encendiendo VMs...")
    for vmid, node in VMS.items():
        start_vm(vmid, node)
        time.sleep(3)

    print("Desconectando OpenVPN...")
    subprocess.run(["pkill", "openvpn"])
    print("Finalizado con éxito")

if __name__ == "__main__":
    main()
