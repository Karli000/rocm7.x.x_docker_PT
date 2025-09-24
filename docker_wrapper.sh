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

echo "=== Schritt 2: Docker-Wrapper installieren ==="
sudo tee /usr/local/bin/docker > /dev/null << 'EOF'
#!/bin/bash

# Finde den echten Docker-Pfad
# -------------------------
REAL_DOCKER=$(which -a docker | grep -v "^/usr/local/bin/" | head -n1)
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

# -------------------------
# Wenn kein 'run', einfach weiterleiten
# -------------------------
if [ "$1" != "run" ]; then
    exec "$REAL_DOCKER" "$@"
fi

shift  # "run" wegsieben

# -------------------------
# Host-GIDs holen
# -------------------------
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

# -------------------------
# Basis-Flags prüfen / setzen
# -------------------------
EXTRA_FLAGS=()
echo "$@" | grep -q -- "--device.*/dev/dri" || EXTRA_FLAGS+=(--device "/dev/dri")
echo "$@" | grep -q -- "--device.*/dev/kfd" || EXTRA_FLAGS+=(--device "/dev/kfd")
echo "$@" | grep -q -- "--security-opt.*seccomp" || EXTRA_FLAGS+=(--security-opt "seccomp=unconfined")

# -------------------------
# GIDs hinzufügen
# -------------------------
[ -n "$VIDEO_GID" ] && EXTRA_FLAGS+=(--group-add "$VIDEO_GID")
[ -n "$RENDER_GID" ] && EXTRA_FLAGS+=(--group-add "$RENDER_GID")

# -------------------------
# Container starten
# -------------------------
CONTAINER_NAME=$(echo "$@" | grep -oP '(?<=--name )\S+' || echo "")
$REAL_DOCKER run "${EXTRA_FLAGS[@]}" "$@" &

# -------------------------
# Optional: Gruppen im Container anlegen (falls GID existiert, wird übersprungen)
# -------------------------
if [ -n "$CONTAINER_NAME" ]; then
    sleep 2
    [ -n "$VIDEO_GID" ] && $REAL_DOCKER exec "$CONTAINER_NAME" groupadd -g "$VIDEO_GID" video 2>/dev/null || true
    [ -n "$RENDER_GID" ] && $REAL_DOCKER exec "$CONTAINER_NAME" groupadd -g "$RENDER_GID" render 2>/dev/null || true
fi
EOF

sudo chmod +x /usr/local/bin/docker
hash -d docker 2>/dev/null || true
echo "✅ Docker-Wrapper installiert!"

echo "=== Schritt 3: Host-ROCm-Version auslesen ==="
ROCM_VER=""
if [ -f /opt/rocm/.info/version ]; then
    ROCM_VER=$(cat /opt/rocm/.info/version | cut -d'.' -f1-3)
elif command -v rocminfo &> /dev/null; then
    ROCM_VER=$(rocminfo | grep "ROCk version" | awk '{print $3}' | cut -d'.' -f1-3)
else
    ROCM_PKG=$(dpkg -l | grep -E "rocm-|amdgpu" | head -1 | awk '{print $2}')
    if [ -n "$ROCM_PKG" ]; then
        ROCM_VER=$(dpkg -s "$ROCM_PKG" | grep Version | awk '{print $2}' | cut -d'.' -f1-3)
    fi
fi

if [ -z "$ROCM_VER" ]; then
    echo "⚠️  ROCm-Version nicht gefunden. Verwende Standardversion 5.7.1"
    ROCM_VER="5.7.1"
fi
echo "Verwende ROCm Version $ROCM_VER für den Container"

echo "=== Schritt 4: Dockerfile für ROCm-Test erstellen ==="
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

echo "=== Schritt 5: Container-Image bauen ==="
docker build -t rocm-test -f Dockerfile.rocmtest .

echo "=== Schritt 6: Container starten und Tools testen ==="
TEST_RESULT=$(docker run -it --rm rocm-test bash -c "
echo '--- /dev/kfd ---'
ls -l /dev/kfd 2>/dev/null && echo '✅ /dev/kfd vorhanden' || echo '❌ /dev/kfd nicht vorhanden'

echo '--- /dev/dri ---'
ls -l /dev/dri 2>/dev/null && echo '✅ /dev/dri vorhanden' || echo '❌ /dev/dri nicht vorhanden'

echo '--- rocminfo ---'
rocminfo 2>/dev/null && echo '✅ rocminfo erfolgreich' || echo '❌ rocminfo fehlgeschlagen'

echo '--- clinfo ---'
clinfo 2>/dev/null && echo '✅ clinfo erfolgreich' || echo '❌ clinfo fehlgeschlagen'
")

echo "$TEST_RESULT"

echo "=== Schritt 7: Ergebnis auswerten ==="
if echo "$TEST_RESULT" | grep -q "✅" && ! echo "$TEST_RESULT" | grep -q "❌"; then
    echo ""
    echo "🎉 ALLE TESTS BESTANDEN! 🎉"
    echo "✅ Docker-Wrapper funktioniert"
    echo "✅ ROCm-Container wurde erstellt"
    echo "✅ GPU-Devices sind verfügbar"
    echo "✅ ROCm-Tools funktionieren"
    echo ""
    echo "Ihr System ist vollständig eingerichtet!"
else
    echo ""
    echo "⚠️  EINIGE TESTS FEHLGESCHLAGEN"
    echo "Überprüfen Sie die ROCm-Installation auf dem Host."
fi

echo "=== Schritt 8: Aufräumen ==="
rm -f Dockerfile.rocmtest
echo "✅ Test abgeschlossen!"
