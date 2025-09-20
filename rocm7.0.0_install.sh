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
wget https://repo.radeon.com/amdgpu/7.0/ubuntu/pool/main/a/amdgpu-insecure-instinct-udev-rules/amdgpu-insecure-instinct-udev-rules_30.10.0.0-2204008.24.04_all.deb
sudo apt install --allow-downgrades -y ./amdgpu-insecure-instinct-udev-rules_30.10.0.0-2204008.24.04_all.deb

echo "=== Schritt 3: ROCm Repository hinzufügen und ROCm installieren ==="
sudo mkdir -p /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.0 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.0/ubuntu noble main
EOF

sudo tee /etc/apt/preferences.d/rocm-pin-600 <<EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
sudo apt update
EOF

wget https://repo.radeon.com/amdgpu-install/7.0/ubuntu/noble/amdgpu-install_7.0.70000-1_all.deb
sudo apt install -y ./amdgpu-install_7.0.70000-1_all.deb
sudo apt update
sudo apt install -y python3-setuptools python3-wheel
sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
sudo apt install -y amdgpu-dkms rocm rocm-opencl-runtime

echo "=== Schritt 4: ROCm Pfade konfigurieren ==="
sudo tee --append /etc/ld.so.conf.d/rocm.conf <<EOF
/opt/rocm/lib
/opt/rocm/lib64
EOF

sudo ldconfig

sudo tee /etc/profile.d/rocm.sh > /dev/null <<EOF
export PATH=\$PATH:/opt/rocm-7.0.0/bin
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/opt/rocm-7.0.0/lib
EOF

source /etc/profile.d/rocm.sh

echo "=== Schritt 5: AMD-Docker Wrapper installieren ==="

# 🔄 Vorherige Version löschen, falls vorhanden
sudo rm -f /usr/local/bin/docker

# 🆕 Neue Datei schreiben
sudo tee /usr/local/bin/docker > /dev/null <<'EOF'
#!/bin/sh
# -------------------------------
# Docker Wrapper
# -------------------------------

# Standard-GPU-Flags
DEFAULT_FLAGS="--device /dev/kfd --device /dev/dri --group-add video --group-add render"

# Echte Docker-Binary finden
if [ -x /usr/bin/docker ]; then REAL_DOCKER=/usr/bin/docker
elif [ -x /bin/docker ]; then REAL_DOCKER=/bin/docker
else echo "Docker nicht gefunden!"; exit 1; fi

# Optional: Symlink /bin/docker setzen, falls nicht vorhanden oder falsch
if [ ! -L /bin/docker ] || [ "$(readlink /bin/docker)" != "/usr/local/bin/docker" ]; then
    sudo ln -sf /usr/local/bin/docker /bin/docker
fi

# Prüfen ob 'run'
if [ "$1" = "run" ]; then
    shift
    FLAGS=""
    for f in $DEFAULT_FLAGS; do
        echo "$@" | grep -q -- "$f" || FLAGS="$FLAGS $f"
    done
    "$REAL_DOCKER" run $FLAGS "$@"
else
    "$REAL_DOCKER" "$@"
fi
EOF

# Ausführbar machen
sudo chmod +x /usr/local/bin/docker

# Feedback und Neustart
echo "✅ Setup abgeschlossen. System wird in 10 Sekunden neu gestartet..."
sleep 10
sudo reboot
