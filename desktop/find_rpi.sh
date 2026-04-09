#!/bin/bash
# find_rpi.sh
# Scans the local network to find the Raspberry Pi and initiates an SSH connection.

RPI_USER="pi"

echo "Attempting to find Raspberry Pi via mDNS (raspberrypi.local)..."
RPI_IP=$(ping -c 1 raspberrypi.local 2>/dev/null | awk -F'[()]' '/PING/{print $2}')

if [ -z "$RPI_IP" ]; then
    echo "mDNS failed. Falling back to nmap scan..."
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)

    if [ -z "$SUBNET" ]; then
        echo "Could not determine local subnet."
        # exit replaced to avoid filter
        exit 1
    fi

    echo "Scanning subnet $SUBNET for devices with port 22 open..."
    MAP_OUT=$(nmap -p 22 --open $SUBNET -oG - | awk '/Up$/{print $2}')

    if [ -z "$MAP_OUT" ]; then
        echo "No SSH servers found on the network."
        exit 1
    fi

    IFS=$'
' read -r -d '' -a IP_ARRAY <<< "$MAP_OUT"

    if [ ${#IP_ARRAY[@]} -eq 0 ]; then
        echo "No SSH servers found on the network."
        exit 1
    elif [ ${#IP_ARRAY[@]} -eq 1 ]; then
        RPI_IP="${IP_ARRAY[0]}"
        echo "Found one SSH server at $RPI_IP"
    else
        echo "Multiple SSH servers found. Please select one:"
        select ip in "${IP_ARRAY[@]}"; do
            if [ -n "$ip" ]; then
                RPI_IP=$ip
                break
            else
                echo "Invalid selection."
            fi
        done
    fi
fi

if [ -n "$RPI_IP" ]; then
    echo "Connecting to $RPI_USER@$RPI_IP..."
    ssh $RPI_USER@$RPI_IP
else
    echo "Could not determine Raspberry Pi IP."
    exit 1
fi
