#!/bin/bash
set -e

echo "=== Schritt 1: AMD-Docker Wrapper installieren ==="
sudo rm -f /usr/local/bin/docker /bin/docker
sudo tee /usr/local/bin/docker > /dev/null <<'EOF'
#!/bin/sh
# Wrapper für AMD GPUs

# Finde echte Docker-Binary
if [ -x /usr/bin/docker ]; then
    REAL_DOCKER=/usr/bin/docker
elif [ -x /bin/docker ]; then
    REAL_DOCKER=/bin/docker
else
    echo "Docker nicht gefunden!"
    exit 1
fi

# Standard-GPU-Geräte prüfen
FLAGS=""
[ -e /dev/kfd ] && FLAGS="$FLAGS --device /dev/kfd"
[ -e /dev/dri/card0 ] && FLAGS="$FLAGS --device /dev/dri/card0"
[ -e /dev/dri/renderD128 ] && FLAGS="$FLAGS --device /dev/dri/renderD128"
FLAGS="$FLAGS --group-add video --group-add render"

# Wenn 'run' aufgerufen, füge GPU-Flags hinzu
if [ "$1" = "run" ]; then
    shift
    exec "$REAL_DOCKER" run $FLAGS "$@"
else
    exec "$REAL_DOCKER" "$@"
fi
EOF
sudo chmod +x /usr/local/bin/docker
echo "Wrapper installiert. Du kannst jetzt 'docker run' oder 'drun' verwenden."
