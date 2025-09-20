echo "=== Schritt 1: Docker installieren ==="
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

echo "=== Schritt 2: Docker-Wrapper mit Group-IDs, Security-Opt und Pfad-Erkennung ==="
sudo tee /usr/local/bin/docker > /dev/null << 'EOF'
#!/bin/bash

# Finde den echten Docker-Pfad (ignoriere /usr/local/bin)
REAL_DOCKER=$(which -a docker | grep -v "^/usr/local/bin/" | head -n1)

# Fallback: Durchsuche bekannte Pfade
if [ -z "$REAL_DOCKER" ] || [ ! -x "$REAL_DOCKER" ]; then
    if [ -x "/usr/bin/docker" ]; then
        REAL_DOCKER="/usr/bin/docker"
    elif [ -x "/bin/docker" ]; then
        REAL_DOCKER="/bin/docker"
    else
        echo "Error: Cannot find real docker binary" >&2
        exit 1
    fi
fi

if [ "$1" != "run" ]; then
    exec "$REAL_DOCKER" "$@"
fi

shift

# Hole die Group-IDs vom Host-System
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

# Einfache Duplikat-Prüfung
EXTRA_FLAGS=()
echo "$@" | grep -q -- "--device.*/dev/dri" || EXTRA_FLAGS+=(--device "/dev/dri")
echo "$@" | grep -q -- "--device.*/dev/kfd" || EXTRA_FLAGS+=(--device "/dev/kfd")
echo "$@" | grep -q -- "--security-opt.*seccomp" || EXTRA_FLAGS+=(--security-opt "seccomp=unconfined")

# Verwende Group-IDs statt Namen
if [ -n "$VIDEO_GID" ]; then
    echo "$@" | grep -q -- "--group-add.*video" || EXTRA_FLAGS+=(--group-add "$VIDEO_GID")
fi

if [ -n "$RENDER_GID" ]; then
    echo "$@" | grep -q -- "--group-add.*render" || EXTRA_FLAGS+=(--group-add "$RENDER_GID")
fi

exec "$REAL_DOCKER" run "${EXTRA_FLAGS[@]}" "$@"
EOF

sudo chmod +x /usr/local/bin/docker

# Shell-Cache leeren (stumm schalten falls nicht existiert)
hash -d docker 2>/dev/null || true

echo "✅ Docker-Wrapper installiert!"
echo "🚀 Starte automatischen Test..."

echo "=== Schritt 3: Host-ROCm-Version auslesen ==="
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
