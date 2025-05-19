#!/bin/bash

# Stop and disable the systemd services
sudo systemctl stop pia-wg.service
sudo systemctl stop pia-wg-monitor.timer
sudo systemctl stop pia-wg-monitor.service
sudo systemctl disable pia-wg.service
sudo systemctl disable pia-wg-monitor.timer
sudo systemctl disable pia-wg-monitor.service

# Remove the systemd service files
sudo rm /etc/systemd/system/pia-wg.service
sudo rm /etc/systemd/system/pia-wg-monitor.service
sudo rm /etc/systemd/system/pia-wg-monitor.timer

# Remove the scripts from /usr/local/bin
sudo rm /usr/local/bin/wg.sh
sudo rm /usr/local/bin/wg-monitor.sh

# Remove the PIA cert from /etc/ssl/certs
sudo rm /etc/ssl/certs/pia.rsa.4096.crt

# Reload systemd to recognize the removed services
sudo systemctl daemon-reload

echo "Uninstallation complete. PIA WireGuard services and files have been removed."
