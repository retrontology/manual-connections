#!/bin/bash

# The wireguard device name
WG_DEV="pia"

# The wireguard certificate file
WG_CERT="/etc/ssl/certs/pia.rsa.4096.crt"

# The tools required
TOOLS=(wg-quick curl jq iptables)

# The server list URL
SERVERLIST_URL='https://serverlist.piaservers.net/vpninfo/servers/v4'

# Import the config
source /etc/default/pia-config

retry=5
usage="${0##*/} <start/stop>"

function parse_args ()
{
    func=$1
}

function check_tool ()
{
  local cmd=$1
  if ! command -v $cmd &>/dev/null
  then
    echo "$cmd could not be found"
    echo "Please install $cmd"
    exit 1
  fi
}

function check_default_tools ()
{
    for i in "${TOOLS[@]}";
    do
        check_tool
    done
}

function get_token ()
{
    #echo "User: $PIA_USER"
    #echo "Pass: $PIA_PASS"
    local tries=0
    while [ $tries -lt $retry ]
    do
        generateTokenResponse=$(curl -s -u "$PIA_USER:$PIA_PASS" "https://privateinternetaccess.com/gtoken/generateToken")
        if [ "$(echo "$generateTokenResponse" | jq -r '.status')" == "OK" ]; then
            break
        fi
        ((tries=tries+1))
    done
    if [ "$(echo "$generateTokenResponse" | jq -r '.status')" != "OK" ]; then
        echo -e "Could not authenticate with the login credentials provided!"
        exit 1
    fi
    wg_token=$(echo "$generateTokenResponse" | jq -r '.token')
    #echo "Token: $wg_token"
}

function get_server_info ()
{
    local tries=0
    while [ $tries -lt $retry ]
    do
        all_region_data=$(curl -s "$SERVERLIST_URL" | head -1)
        regionData="$( echo $all_region_data | jq --arg REGION_ID "$PIA_REGION" -r '.regions[] | select(.id==$REGION_ID)')"
        if [[ $regionData ]]; then
            break
        fi
        ((tries=tries+1))
    done
    if [[ ! $regionData ]]; then
        echo -e "The REGION_ID $region is not valid."
        exit 1
    fi
    #echo $regionData
    wg_ip="$(echo $regionData | jq -r '.servers.wg[0].ip')"
    wg_cn="$(echo $regionData | jq -r '.servers.wg[0].cn')"
    #echo "WG_IP: $wg_ip"
    #echo "WG_CN: $wg_cn"
}

function fw_reset ()
{
    # Reset iptables
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo iptables -t mangle -F
    sudo iptables -t mangle -X
}

function fw_start ()
{
    # Save iptables rules as backup
    #sudo iptables-save > /etc/iptables/rules.v4.bak

    # Reset iptables
    fw_reset

    # Block all traffic
    sudo iptables -P INPUT DROP
    sudo iptables -P OUTPUT DROP
    sudo iptables -P FORWARD DROP

    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established/related connections
    sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow initial WireGuard handshake
    sudo iptables -A OUTPUT -d $wg_ip -p udp --dport $wg_port -j ACCEPT

    # Allow DNS via wireguard DNS server
    sudo iptables -A OUTPUT -o $WG_DEV -p udp --dport 53 -d $dnsServer -j ACCEPT

    # Allow all traffic through wireguard interface
    sudo iptables -A OUTPUT -o $WG_DEV -j ACCEPT
    sudo iptables -A INPUT -i $WG_DEV -j ACCEPT

    # Allow local network traffic
    sudo iptables -A INPUT -i $LOCAL_DEV -s $LOCAL_NET -j ACCEPT
    sudo iptables -A OUTPUT -o $LOCAL_DEV -d $LOCAL_NET -j ACCEPT

    # Save iptables rules
    sudo iptables-save > /etc/iptables/rules.v4
}

function fw_stop ()
{
    # Reset iptables
    fw_reset

    # Restore iptables rules
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT

    # Save iptables rules
    sudo iptables-save > /etc/iptables/rules.v4
}

function wg_start ()
{
    get_token
    privKey="$(wg genkey)"
    pubKey="$( echo "$privKey" | wg pubkey)"
    #echo "$privKey :::: $pubKey"
    #echo "$wg_cn::$wg_ip:"
    local tries=0
    while [ $tries -lt $retry ]
    do
        wireguard_json=$(curl -s -G \
        --connect-to "${wg_cn}::${wg_ip}:" \
        --cacert "${WG_CERT}" \
        --data-urlencode "pt=${wg_token}" \
        --data-urlencode "pubkey=${pubKey}" \
        "https://${wg_cn}:1337/addKey" )
        #echo $wireguard_json
        if [ "$(echo "$wireguard_json" | jq -r '.status')" == "OK" ]; then
            break
        fi
        ((tries=tries+1))
    done
    if [ "$(echo "$wireguard_json" | jq -r '.status')" != "OK" ]; then
        >&2 echo -e "Server did not return OK. Stopping now."
        exit 1
    fi
    wg_port="$(echo "$wireguard_json" | jq -r '.server_port')"
    dnsServer="$(echo "$wireguard_json" | jq -r '.dns_servers[0]')"
    wg_stop
    sudo mkdir -p /etc/wireguard
    echo "
    [Interface]
    Address = $(echo "$wireguard_json" | jq -r '.peer_ip')
    PrivateKey = $privKey
    DNS = $dnsServer
    [Peer]
    PersistentKeepalive = 25
    PublicKey = $(echo "$wireguard_json" | jq -r '.server_key')
    AllowedIPs = 0.0.0.0/0
    Endpoint = ${wg_ip}:${wg_port}
    " | sudo tee /etc/wireguard/$WG_DEV.conf || exit 1
    wg-quick up $WG_DEV || exit 1
}

function wg_stop ()
{
    sudo wg-quick down $WG_DEV
    sudo rm /etc/wireguard/$WG_DEV.conf
}

function start ()
{
    check_default_tools
    get_server_info
    wg_start
    fw_start
}

function stop ()
{
    check_default_tools
    wg_stop
    fw_stop
}

parse_args $1
case $func in
    start)
        start;;
    stop)
        stop;;
    *)
        echo $usage
        exit 1
        ;;
esac
