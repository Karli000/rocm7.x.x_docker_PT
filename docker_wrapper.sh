#!/bin/bash
set -e

echo "=== Schritt: AMD-Docker Wrapper installieren ==="

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
  exec "$REAL_DOCKER" run $FLAGS "$@"
else
  exec "$REAL_DOCKER" "$@"
fi
EOF

# Ausführbar machen
sudo chmod +x /usr/local/bin/docker
