#!/bin/bash
set -e

echo "=== Schritt 0: Docker installieren ==="
if ! command -v docker &> /dev/null; then
  echo "Docker wird installiert..."
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "Docker erfolgreich installiert."
else
  echo "Docker ist bereits installiert."
fi

echo "=== Schritt 1: AMD-Docker Wrapper installieren ==="
sudo rm -f /usr/local/bin/docker
sudo tee /usr/local/bin/docker > /dev/null <<'EOF'
#!/bin/sh
DEFAULT_FLAGS="--device /dev/kfd --device /dev/dri --group-add video --group-add render"
if [ -x /usr/bin/docker ]; then REAL_DOCKER=/usr/bin/docker
elif [ -x /bin/docker ]; then REAL_DOCKER=/bin/docker
else echo "Docker nicht gefunden!"; exit 1; fi
if [ ! -L /bin/docker ] || [ "$(readlink /bin/docker)" != "/usr/local/bin/docker" ]; then
    sudo ln -sf /usr/local/bin/docker /bin/docker
fi
if [ "$1" = "run" ]; then
    shift
    FLAGS=""
    for f in $DEFAULT_FLAGS; do
        echo "$@" | grep -q -- "$f" || FLAGS="$FLAGS $f"
    done
    exec "$REAL_DOCKER" run $FLAGS "$@"
else
    exec "$REAL_DOCKER" "$@"
fi
EOF
sudo chmod +x /usr/local/bin/docker
echo "Wrapper installiert. Du kannst jetzt 'docker run' oder 'drun' verwenden."

echo "=== Schritt 2: Host-ROCm-Version auslesen ==="
if ! command -v dpkg-query &> /dev/null || ! dpkg-query -W rocm &> /dev/null; then
  echo "ROCm ist auf dem Host nicht installiert. Bitte zuerst ROCm installieren."
  exit 1
fi
ROCM_VER=$(dpkg-query -W -f='${Version}' rocm | cut -d'.' -f1-3)
echo "Verwende ROCm Version $ROCM_VER für den Container"

echo "=== Schritt 3: Dockerfile für ROCm-Test erstellen ==="
cat <<EOF > Dockerfile.rocmtest
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y wget gnupg2 software-properties-common clinfo pciutils && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings && \\
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor | tee /etc/apt/keyrings/rocm.gpg > /dev/null && \\
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/$ROCM_VER noble main" > /etc/apt/sources.list.d/rocm.list && \\
    apt update && apt install -y rocminfo && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
EOF

echo "=== Schritt 4: Container-Image bauen ==="
docker build -t rocm-test -f Dockerfile.rocmtest .

echo "=== Schritt 5: Container starten und Tools testen ==="
docker run -it --rm rocm-test bash -c "
echo '--- /dev/kfd ---'
ls -l /dev/kfd || echo 'Nicht vorhanden'

echo '--- /dev/dri ---'
ls -l /dev/dri || echo 'Nicht vorhanden'

echo '--- rocminfo ---'
rocminfo || echo 'rocminfo fehlgeschlagen'

echo '--- clinfo ---'
clinfo || echo 'clinfo fehlgeschlagen'
"
