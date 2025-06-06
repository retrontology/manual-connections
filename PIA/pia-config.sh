#!/bin/bash

# Local networks
declare -A LOCAL_NET=(
    ["eth0"]="192.168.1.0/24;192.168.2.0/24"
    ["eth1"]="192.168.10.0/24"
)

# The username and password for the PIA account
PIA_USER="your_username"
PIA_PASS="your_password"

# The region of the PIA server
PIA_REGION="fi"
