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
# Verzeichnis sicherstellen
sudo mkdir -p /usr/local/bin
# Alte Wrapper-Datei löschen, falls vorhanden
sudo rm -f /usr/local/bin/docker

sudo tee /usr/local/bin/docker > /dev/null << 'EOF'
#!/bin/bash

#!/bin/bash

# Finde den echten Docker-Pfad
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

# Wenn kein 'run', einfach weiterleiten
if [ "$1" != "run" ]; then
    exec "$REAL_DOCKER" "$@"
fi

shift  # "run" entfernen

# -------------------------
# GPU-Flags, die ergänzt werden sollen
EXTRA_FLAGS=()
echo "$@" | grep -q -- "--privileged"       || EXTRA_FLAGS+=(--privileged)
echo "$@" | grep -q -- "--network"          || EXTRA_FLAGS+=(--network=host)
echo "$@" | grep -q -- "--device=/dev/kfd"  || EXTRA_FLAGS+=(--device=/dev/kfd)
echo "$@" | grep -q -- "--device=/dev/dri"  || EXTRA_FLAGS+=(--device=/dev/dri)
echo "$@" | grep -q -- "--ipc"              || EXTRA_FLAGS+=(--ipc=host)
echo "$@" | grep -q -- "--cap-add=SYS_PTRACE" || EXTRA_FLAGS+=(--cap-add=SYS_PTRACE)
echo "$@" | grep -q -- "--security-opt"     || EXTRA_FLAGS+=(--security-opt=seccomp=unconfined)
echo "$@" | grep -q -- "--shm-size"         || EXTRA_FLAGS+=(--shm-size=16G)

# MultigPU: alle relevanten Devices automatisch durchreichen
for dev in /dev/dri/card* /dev/dri/renderD* /dev/kfd; do
  [ -e "$dev" ] && echo "$@" | grep -q -- "--device=$dev" || EXTRA_FLAGS+=(--device="$dev")

done

# -------------------------
# Container starten
exec "$REAL_DOCKER" run "${EXTRA_FLAGS[@]}" "$@"
EOF

sudo chmod +x /usr/local/bin/docker
hash -d docker 2>/dev/null || true
echo "✅ Docker-Wrapper installiert!"

