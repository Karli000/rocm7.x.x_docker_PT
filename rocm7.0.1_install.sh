#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/rocm-install.log"
exec > >(tee -i "$LOGFILE") 2>&1

echo "=== ROCm 7.0.1 Installer (gehärtete Version) ==="

# --- Schritt 0: Checks ---
if [[ $EUID -eq 0 ]]; then
  echo "Bitte nicht direkt als root ausführen, sondern mit sudo starten."
  exit 1
fi

UBUNTU_VERSION=$(lsb_release -cs)
if [[ "$UBUNTU_VERSION" != "noble" ]]; then
  echo "⚠️ Dieses Skript ist für Ubuntu Noble getestet, gefunden: $UBUNTU_VERSION"
  read -p "Trotzdem fortfahren? (y/N) " ans
  [[ "$ans" == "y" ]] || exit 1
fi

if ! lspci | grep -qi "AMD/ATI"; then
  echo "❌ Keine AMD GPU gefunden."
  exit 1
fi

# --- Schritt 1: System aktualisieren ---
echo "=== Schritt 1: System aktualisieren und Grundpakete installieren ==="
sudo apt update
sudo apt upgrade -y   # KEIN dist-upgrade
sudo apt install -y build-essential update-manager-core wget curl gnupg lsb-release software-properties-common

# --- Schritt 2: Gruppen konfigurieren und AMDGPU Udev-Regeln installieren ---
echo "=== Schritt 2: Gruppen konfigurieren und AMDGPU Udev-Regeln installieren ==="
TARGET_USER="${SUDO_USER:-$(logname)}"
sudo groupadd -f docker
sudo usermod -aG docker,video,render "$TARGET_USER"

# AMDGPU Udev Regeln (immer installieren)
wget https://repo.radeon.com/amdgpu/30.10.1/ubuntu/pool/main/a/amdgpu-insecure-instinct-udev-rules/amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb
sudo apt install --allow-downgrades -y ./amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb

# --- Schritt 3: ROCm Repository ---
echo "=== Schritt 3: ROCm Repository hinzufügen und ROCm installieren ==="
sudo mkdir -p /etc/apt/keyrings
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.0.1 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.0.1/ubuntu noble main
EOF

sudo tee /etc/apt/preferences.d/rocm-pin-600 <<EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

sudo apt update
wget https://repo.radeon.com/amdgpu-install/7.0.1/ubuntu/noble/amdgpu-install_7.0.1.70001-1_all.deb
sudo apt install -y ./amdgpu-install_7.0.1.70001-1_all.deb

sudo apt install -y python3-setuptools python3-wheel
sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"

# ROCm Basispakete
sudo apt install -y amdgpu-dkms rocm rocm-hip-libraries rocm-hip-runtime \
  rocm-language-runtime rocm-ml-libraries rocm-opencl-runtime amdgpu-lib \
  rocm-developer-tools rocm-hip-sdk rocm-ml-sdk rocm-opencl-sdk rocm-openmp-sdk

# Vulkan Stack
sudo apt install -y libvulkan1 vulkan-utils vulkan-validationlayers vulkan-tools mesa-vulkan-drivers
sudo apt install -y amdgpu-vulkan-driver amdgpu-pro-vulkan-driver || true

# --- Schritt 4: Pfade konfigurieren ---
echo "=== Schritt 4: Pfade konfigurieren ==="
sudo tee /etc/ld.so.conf.d/rocm.conf <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF
sudo ldconfig

sudo tee /etc/profile.d/rocm.sh > /dev/null <<EOF
export PATH=\$PATH:/opt/rocm-7.0.1/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm-7.0.1/lib
EOF

# --- Cleanup ---
rm -f amdgpu-insecure-instinct-udev-rules_*.deb amdgpu-install_*.deb

# --- Testausgabe ---
echo "=== ROCm / GPU Funktionstest ==="

if command -v /opt/rocm-7.0.1/bin/rocminfo >/dev/null && /opt/rocm-7.0.1/bin/rocminfo >/dev/null 2>&1; then
  echo "rocminfo: verfügbar ✅"
else
  echo "rocminfo: nicht gefunden ❌"
fi

if command -v clinfo >/dev/null && clinfo >/dev/null 2>&1; then
  echo "clinfo: verfügbar ✅"
else
  echo "clinfo: nicht gefunden ❌"
fi

if command -v vulkaninfo >/dev/null && vulkaninfo >/dev/null 2>&1; then
  echo "vulkaninfo: verfügbar ✅"
else
  echo "vulkaninfo: nicht gefunden ❌"
fi

echo "✅ Setup abgeschlossen."
echo "Bitte starte das System manuell neu, wenn es dir passt."
