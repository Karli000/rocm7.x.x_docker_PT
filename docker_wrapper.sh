#!/bin/sh
# Universeller AMD-Docker-Wrapper, korrekt ohne doppelte Flags

# Finde die echte Docker-Binary
if [ -x /usr/bin/docker ]; then
    REAL_DOCKER=/usr/bin/docker
elif [ -x /bin/docker ]; then
    REAL_DOCKER=/bin/docker
else
    echo "Docker-Binary wurde nicht gefunden!"
    exit 1
fi

# Funktion, die ein Flag nur hinzufügt, wenn es nicht schon vorhanden ist
append_flag() {
    case " $FLAGS " in
        *" $1 "*) : ;;  # schon vorhanden, nichts tun
        *) FLAGS="$FLAGS $1" ;;
    esac
}

# Standard-GPU-Geräte prüfen und Flags hinzufügen
[ -e /dev/kfd ] && append_flag "--device /dev/kfd"
[ -e /dev/dri/card0 ] && append_flag "--device /dev/dri/card0"
[ -e /dev/dri/renderD128 ] && append_flag "--device /dev/dri/renderD128"

# Gruppen hinzufügen
append_flag "--group-add video"
append_flag "--group-add render"

# Security-Option hinzufügen
append_flag "--security-opt seccomp=unconfined"

# Wenn 'run' aufgerufen wird, Flags hinzufügen
if [ "$1" = "run" ]; then
    shift
    exec "$REAL_DOCKER" run $FLAGS "$@"
else
    exec "$REAL_DOCKER" "$@"
fi
