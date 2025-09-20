#!/bin/bash

# MirrorMaster™ – Docker Registry Mirror mit Firewall & Auto-Cleanup

set -e

echo "📦 System aktualisieren..."
apt update && apt upgrade -y

echo "🐳 Docker installieren..."
apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "📁 Registry-Verzeichnisse erstellen..."
mkdir -p /opt/registry/data
mkdir -p /opt/registry/config

echo "🌐 IP-Adresse erkennen..."
SERVER_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
echo "➡️ Mirror-IP: $SERVER_IP"

echo "📝 Registry-Konfiguration schreiben..."
tee /opt/registry/config/config.yml > /dev/null <<EOF
version: 0.1
log:
  fields:
    service: registry
storage:
  filesystem:
    rootdirectory: /var/lib/registry
  cache:
    blobdescriptor: inmemory
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io
EOF

echo "🔓 Firewall konfigurieren..."
apt install -y ufw
ufw allow ssh
ufw allow 5000/tcp
ufw --force enable

echo "🧹 Alten Container entfernen (falls vorhanden)..."
docker rm -f registry-mirror || echo "Kein vorhandener Container zu entfernen."

echo "🚀 Registry Mirror starten..."
docker run -d \
  --restart=always \
  --name registry-mirror \
  -p 5000:5000 \
  -v /opt/registry/data:/var/lib/registry \
  -v /opt/registry/config/config.yml:/etc/docker/registry/config.yml:ro \
  registry:2

echo "📺 iftop installieren..."
apt install -y iftop

echo "🧠 Cleanup-Skript erstellen..."
tee /usr/local/bin/docker-image-cleanup.sh > /dev/null <<'EOF'
#!/bin/bash

LIMIT=85
TARGET=70

get_usage() {
  df / | tail -1 | awk '{print $5}' | tr -d '%'
}

USAGE=$(get_usage)
echo "📊 Speicherbelegung: $USAGE%"

if [ "$USAGE" -lt "$LIMIT" ]; then
  echo "✅ Speicher unter $LIMIT% – kein Cleanup nötig."
  exit 0
fi

echo "⚠️ Speicher über $LIMIT% – starte Image-Cleanup..."

RUNNING_IMAGES=$(docker ps --format '{{.Image}}' | sort | uniq)
ALL_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.CreatedSince}}' | sort -k3)

for LINE in $ALL_IMAGES; do
  IMAGE_NAME=$(echo "$LINE" | awk '{print $1}')
  IMAGE_ID=$(echo "$LINE" | awk '{print $2}')

  if echo "$RUNNING_IMAGES" | grep -q "$IMAGE_NAME"; then
    echo "⏸️ Läuft gerade: $IMAGE_NAME – wird nicht gelöscht."
    continue
  fi

  echo "🔥 Entferne Image: $IMAGE_NAME ($IMAGE_ID)"
  docker rmi -f "$IMAGE_ID" || echo "⚠️ Konnte $IMAGE_ID nicht löschen"
  sleep 2

  USAGE=$(get_usage)
  echo "📉 Neue Auslastung: $USAGE%"
  if [ "$USAGE" -lt "$TARGET" ]; then
    echo "✅ Speicher unter $TARGET% – Cleanup abgeschlossen."
    break
  fi
done
EOF

chmod +x /usr/local/bin/docker-image-cleanup.sh

echo "🕒 systemd-Service & Timer für Cleanup einrichten..."
tee /etc/systemd/system/docker-image-cleanup.service > /dev/null <<EOF
[Unit]
Description=Stündlicher Docker Image Cleanup bei Speicherüberlastung

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-image-cleanup.sh
EOF

tee /etc/systemd/system/docker-image-cleanup.timer > /dev/null <<EOF
[Unit]
Description=Stündlich Docker Images löschen bei Bedarf

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now docker-image-cleanup.timer

echo "✅ Setup abgeschlossen!"
echo "🔗 Mirror läuft unter: http://$SERVER_IP:5000/v2/"
echo "📡 Live-Traffic im Terminal: sudo iftop"
echo "🧹 Cleanup läuft stündlich, wenn Speicher >85% – stoppt bei <70%"
