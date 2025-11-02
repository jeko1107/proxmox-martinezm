#!/usr/bin/env python3
import requests
import os
import time
from urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

PROXMOX_IP = os.environ["PROXMOX_IP"]
TOKEN = os.environ["PROXMOX_TOKEN"]
API_URL = f"https://{PROXMOX_IP}/api2/json"

VMS = {
    "1286": "proxS4",
    "1288": "proxS3",
    "1110": "proxS3",
    "1109": "proxS7",
}

print("Encendiendo VMs en Proxmox...")
for vmid, node in VMS.items():
    url = f"{API_URL}/nodes/{node}/qemu/{vmid}/status/start"
    headers = {"Authorization": TOKEN}
    try:
        r = requests.post(url, headers=headers, verify=False, timeout=10)
        status = "ENCENDIDA" if r.status_code == 200 else f"ERROR {r.status_code}"
        print(f"  VM {vmid} ({node}): {status}")
    except Exception as e:
        print(f"  VM {vmid}: ERROR de red - {e}")
    time.sleep(3)

print("¡Todas las VMs iniciadas!")
