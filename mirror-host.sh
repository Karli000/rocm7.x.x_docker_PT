#!/bin/bash

# IP-Adresse des Mirror-Servers abfragen
read -p "🖧 Bitte gib die IP-Adresse deines Docker-Mirror-Servers ein: " MIRROR_IP

# Pfad zur Docker-Konfig
CONFIG_PATH="/etc/docker/daemon.json"

# Sicherstellen dass /etc/docker existiert
sudo mkdir -p /etc/docker

# Backup der alten Konfig
if [ -f "$CONFIG_PATH" ]; then
    sudo cp $CONFIG_PATH ${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)
    echo "📦 Backup der alten Konfig erstellt"
fi

# Neue Konfiguration schreiben
sudo tee $CONFIG_PATH > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "registry-mirrors": [
    "http://$MIRROR_IP:5000"
  ],
  "insecure-registries": [
    "$MIRROR_IP:5000"
  ]
}
EOF

# Docker neu starten
echo "🔄 Docker wird neu gestartet..."
sudo systemctl restart docker

# Prüfen ob Docker läuft
if sudo systemctl is-active --quiet docker; then
    echo "✅ Mirror-Konfiguration abgeschlossen für IP: $MIRROR_IP"
    echo "📋 Konfiguration gespeichert in: $CONFIG_PATH"
else
    echo "❌ Docker konnte nicht gestartet werden. Bitte prüfen:"
    echo "   sudo systemctl status docker"
    echo "   sudo journalctl -xe"
fi
