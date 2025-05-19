#!/bin/bash

# Copy the PIA cert to /etc/ssl/certs/
sudo cp PIA/pia.rsa.4096.crt /etc/ssl/certs/

# Copy the scripts to /usr/local/bin
sudo cp PIA/pia.sh /usr/local/bin/pia.sh
sudo cp PIA/pia-monitor.sh /usr/local/bin/pia-monitor.sh
sudo chmod +x /usr/local/bin/pia.sh

# Copy the config to /etc/default/
sudo cp PIA/pia-config.sh /etc/default/pia-config

# Copy the systemd files
sudo cp systemd/pia-wg.service /etc/systemd/system/
sudo cp systemd/pia-wg-monitor.service /etc/systemd/system/
sudo cp systemd/pia-wg-monitor.timer /etc/systemd/system/

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Inform the user how to enable and start the service
echo "Installation complete. To enable and start the service:"
echo "sudo systemctl enable pia-wg.service"
echo "sudo systemctl start pia-wg.service"
