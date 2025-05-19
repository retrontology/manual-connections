#!/bin/bash

# Check if we can reach the internet through WireGuard
if ! ping -c 1 -W 5 -I wg0 1.1.1.1 > /dev/null 2>&1; then
    echo "WireGuard connection appears to be down, restarting service..."
    systemctl restart pia-wg.service
fi
