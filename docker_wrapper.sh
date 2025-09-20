sudo tee /usr/local/bin/docker > /dev/null << 'EOF'
#!/bin/bash

# Docker-Wrapper mit Group-IDs, Security-Opt und Pfad-Erkennung

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

# Starte den Container-Test
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/docker_test.sh)
