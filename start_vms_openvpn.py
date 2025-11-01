#!/usr/bin/env python3
import subprocess
import time
import sys
import requests
import os
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

# Secrets inyectados por GitHub
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
    cmd = [
        "openvpn",
        "--config", "/tmp/instituto.ovpn",
        "--auth-user-pass", "/tmp/auth.txt",
        "--ca", "/tmp/cacert.pem",
        "--daemon"
    ]
    subprocess.run(cmd, check=False)
    time.sleep(20)

    # Verifica con ping
    for _ in range(3):
        result = subprocess.run(["ping", "-c", "1", PROXMOX_IP], capture_output=True, timeout=10)
        if result.returncode == 0:
            print("VPN conectada")
            return True
        time.sleep(5)
    print("No se pudo conectar a la VPN")
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
        print(f"Error de red: {e}")

def main():
    if not connect_vpn():
        sys.exit(1)

    print("Encendiendo VMs...")
    for vmid, node in VMS.items():
        start_vm(vmid, node)
        time.sleep(3)

    print("Desconectando...")
    subprocess.run(["pkill", "openvpn"])
    print("Finalizado")

if __name__ == "__main__":
    main()