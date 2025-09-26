#!/bin/bash

# Pfade
SCRIPT_PATH="/usr/local/bin/gpu_fan_control.sh"
SERVICE_PATH="/etc/systemd/system/gpu-fan.service"

# Interaktive Eingabe
read -p "Minimale Zieltemperatur (°C): " MIN_C
read -p "Maximale Zieltemperatur (°C): " MAX_C

# Umrechnung in Milligrad Celsius
MIN_TEMP=$((MIN_C * 1000))
MAX_TEMP=$((MAX_C * 1000))

# Lüfterregel-Skript schreiben
cat << EOF | sudo tee $SCRIPT_PATH > /dev/null
#!/bin/bash

# hwmon-Pfad automatisch finden
HWMON=\$(find /sys/class/hwmon/ -type l -exec bash -c 'grep -q amdgpu {}/name && echo {}' \;)

echo 1 > "\$HWMON/pwm1_enable"

MIN_TEMP=$MIN_TEMP
MAX_TEMP=$MAX_TEMP
MIN_PWM=0
MAX_PWM=255

while true; do
  TEMP=\$(cat "\$HWMON/temp1_input")

  if [ "\$TEMP" -lt "\$MIN_TEMP" ]; then
    PWM=\$MIN_PWM
  elif [ "\$TEMP" -gt "\$MAX_TEMP" ]; then
    PWM=\$MAX_PWM
  else
    PWM=\$(( (\$TEMP - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) ))
  fi

  echo \$PWM > "\$HWMON/pwm1"
  sleep 1
done
EOF

# Skript ausführbar machen
sudo chmod +x $SCRIPT_PATH

# systemd-Dienst schreiben
cat << EOF | sudo tee $SERVICE_PATH > /dev/null
[Unit]
Description=Custom GPU Fan Control
After=multi-user.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Dienst aktivieren und starten
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable gpu-fan.service
sudo systemctl start gpu-fan.service

# Status anzeigen
sudo systemctl status gpu-fan.service
