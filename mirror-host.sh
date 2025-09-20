#!/bin/bash

# IP-Adresse des Mirror-Servers abfragen
read -p "🖧 Bitte gib die IP-Adresse deines Docker-Mirror-Servers ein: " MIRROR_IP

# Pfad zur Docker-Konfig
CONFIG_PATH="/etc/docker/daemon.json"

# Backup der alten Konfig
sudo cp $CONFIG_PATH ${CONFIG_PATH}.backup

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

echo "✅ Mirror-Konfiguration abgeschlossen für IP: $MIRROR_IP"
