#!/bin/bash
set -e

echo "=== Schritt 1: System aktualisieren und Grundpakete installieren ==="
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y update-manager-core build-essential

echo "=== Schritt 2: Gruppen konfigurieren und AMDGPU Udev-Regeln installieren ==="
TARGET_USER="${SUDO_USER:-$(logname)}"
sudo groupadd docker || true
sudo usermod -aG docker,video,render "$TARGET_USER"
sudo usermod -aG docker,video,render root

sudo apt update
wget https://repo.radeon.com/amdgpu/30.10.1/ubuntu/pool/main/a/amdgpu-insecure-instinct-udev-rules/amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb
sudo apt install --allow-downgrades -y ./amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb

echo "=== Schritt 3: ROCm Repository hinzufügen und ROCm installieren ==="
sudo mkdir -p /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

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
sudo apt update
sudo apt install -y python3-setuptools python3-wheel
sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install -y amdgpu-dkms rocm rocm-hip-libraries rocm-hip-runtime rocm-language-runtime rocm-ml-libraries rocm-opencl-runtime amdgpu-lib rocm-developer-tools rocm-hip-sdk rocm-ml-sdk rocm-opencl-sdk rocm-openmp-sdk vulkan-tools libvulkan-dev mesa-utils

echo "=== Schritt 4: ROCm Pfade konfigurieren ==="
sudo tee --append /etc/ld.so.conf.d/rocm.conf <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF

sudo ldconfig

sudo tee /etc/profile.d/rocm.sh > /dev/null <<EOF
export PATH=\$PATH:/opt/rocm-7.0.1/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm-7.0.1/lib
EOF

source /etc/profile.d/rocm.sh

# Feedback und Neustart
echo "✅ Setup abgeschlossen. System wird in 10 Sekunden neu gestartet..."
sleep 10
sudo reboot
