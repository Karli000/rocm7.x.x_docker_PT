#!/bin/bash
set -e

echo "=== Schritt 1: System aktualisieren und Grundpakete installieren ==="
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y update-manager-core build-essential python3-setuptools python3-wheel
sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"

echo "=== Schritt 2: Gruppen konfigurieren und AMDGPU Udev-Regeln installieren ==="
TARGET_USER="${SUDO_USER:-$(logname)}"
sudo groupadd docker || true
sudo usermod -aG docker,video,render "$TARGET_USER"
sudo usermod -aG docker,video,render root

sudo apt update
wget https://repo.radeon.com/amdgpu/30.10.1/ubuntu/pool/main/a/amdgpu-insecure-instinct-udev-rules/amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb
sudo apt install ./amdgpu-insecure-instinct-udev-rules_30.10.1.0-2212064.24.04_all.deb

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
sudo apt install ./amdgpu-install_7.0.1.70001-1_all.deb
sudo apt install -y amdgpu-dkms rocm rocm-opencl-runtime

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

echo "=== Schritt 5: AMD-Docker Wrapper installieren ==="
sudo tee /usr/local/bin/amd-docker > /dev/null <<'EOF'
#!/bin/bash

REAL_DOCKER="$(command -v docker | grep -v /usr/local/bin/amd-docker || true)"
[ -z "$REAL_DOCKER" ] && [ -x /usr/bin/docker ] && REAL_DOCKER="/usr/bin/docker"
[ -z "$REAL_DOCKER" ] && [ -x /bin/docker ] && REAL_DOCKER="/bin/docker"
[ -z "$REAL_DOCKER" ] && echo "❌ Konnte echte Docker-Binary nicht finden!" >&2 && exit 1

contains_flag() {
    local flag="$1"
    shift
    for arg in "$@"; do
        [[ "$arg" == "$flag"* ]] && return 0
    done
    return 1
}

if [ "$1" == "run" ]; then
    shift
    args=("$@")
    extra_flags=()

    # 🎮 GPU-Devices hinzufügen
    for dev in /dev/kfd /dev/dri /dev/dri/card* /dev/dri/renderD*; do
        [ -e "$dev" ] && ! contains_flag "--device=$dev" "${args[@]}" && extra_flags+=(--device="$dev")
    done

    # 👥 Gruppenrechte hinzufügen
    for grp in render video; do
        GID=$(getent group "$grp" | cut -d: -f3)
        [ -n "$GID" ] && ! contains_flag "--group-add $GID" "${args[@]}" && extra_flags+=(--group-add "$GID")
    done

    # 🧨 Docker ausführen
    echo "📦 Zusätzliche Flags: ${extra_flags[*]}" >&2
    exec "$REAL_DOCKER" run -it "${extra_flags[@]}" "${args[@]}"
else
    exec "$REAL_DOCKER" "$@"
fi

EOF

sudo chmod +x /usr/local/bin/amd-docker

echo "=== Schritt 6: Bashrc-Funktion für docker run einfügen ==="
cat <<'EOF' >> ~/.bashrc

# 🐳 AMD-Docker-Funktion: ersetzt docker run durch amd-docker run
docker() {
    if [ "$1" == "run" ]; then
        shift
        amd-docker run "$@"
    else
        command docker "$@"
    fi
}
EOF

source ~/.bashrc

echo "✅ Setup abgeschlossen. System wird jetzt neu gestartet."
sudo reboot
