#!/bin/bash
# find_rpi.sh
# Scans the local network to find the Raspberry Pi and initiates an SSH connection.

# Default to 'root' user unless passed as an argument
RPI_USER=${1:-root}

echo "Attempting to find Raspberry Pi via mDNS (raspberrypi.local)..."
RPI_IP=$(ping -c 1 raspberrypi.local 2>/dev/null | awk -F'[()]' '/PING/{print $2}')

if [ -z "$RPI_IP" ]; then
    echo "mDNS failed. Falling back to ARP scan..."

    # Get a list of reachable IPs from the ARP table
    MAP_OUT=$(ip neigh | awk '/REACHABLE|STALE/{print $1}')

    if [ -z "$MAP_OUT" ]; then
        echo "No servers found on the network."
        return 1 2>/dev/null || kill -INT $$
    fi

    IFS=$'\n' read -r -d '' -a IP_ARRAY <<< "$MAP_OUT"

    # Filter out gateway usually .1 or .254
    FILTERED_IPS=()
    for ip in "${IP_ARRAY[@]}"; do
        if [[ ! "$ip" =~ \.1$ ]] && [[ ! "$ip" =~ \.254$ ]]; then
            FILTERED_IPS+=("$ip")
        fi
    done

    if [ ${#FILTERED_IPS[@]} -eq 0 ]; then
        echo "No SSH servers found on the network."
        return 1 2>/dev/null || kill -INT $$
    elif [ ${#FILTERED_IPS[@]} -eq 1 ]; then
        RPI_IP="${FILTERED_IPS[0]}"
        echo "Found one potential SSH server at $RPI_IP"
    else
        echo "Multiple servers found. Please select the Raspberry Pi (often 192.168.1.5):"
        select ip in "${FILTERED_IPS[@]}"; do
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
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $RPI_USER@$RPI_IP

    if [ $? -ne 0 ]; then
        echo "========================================================================="
        echo "SSH Connection Failed. Modern Raspberry Pi OS images no longer have a "
        echo "default user. If you haven't created a user yet, please use the"
        echo "./prepare_sd_card.sh script to mount your SD card and initialize a user."
        echo "Or pass the user as an argument: ./find_rpi.sh <username>"
        echo "========================================================================="
    fi
else
    echo "Could not determine Raspberry Pi IP."
    return 1 2>/dev/null || kill -INT $$
fi
