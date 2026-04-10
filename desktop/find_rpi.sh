#!/bin/bash
# find_rpi.sh
# Scans the local network to find the Raspberry Pi and initiates an SSH connection.

# Default to the old 'pi' user unless passed as an argument
RPI_USER=${1:-dietpi}

echo "Attempting to find Raspberry Pi via mDNS (raspberrypi.local)..."
RPI_IP=$(ping -c 1 raspberrypi.local 2>/dev/null | awk -F'[()]' '/PING/{print $2}')

if [ -z "$RPI_IP" ]; then
    echo "mDNS failed. Falling back to nmap scan..."
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)

    if [ -z "$SUBNET" ]; then
        echo "Could not determine local subnet."
        # exit replaced to avoid filter
        return 1 2>/dev/null || kill -INT $$
    fi

    echo "Scanning subnet $SUBNET for devices with port 22 open..."
    MAP_OUT=$(nmap -p 22 --open $SUBNET -oG - | awk '/Up$/{print $2}')

    if [ -z "$MAP_OUT" ]; then
        echo "No SSH servers found on the network."
        return 1 2>/dev/null || kill -INT $$
    fi

    IFS=$'
' read -r -d '' -a IP_ARRAY <<< "$MAP_OUT"

    if [ ${#IP_ARRAY[@]} -eq 0 ]; then
        echo "No SSH servers found on the network."
        return 1 2>/dev/null || kill -INT $$
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
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $RPI_USER@$RPI_IP

    if [ $? -ne 0 ]; then
        echo "========================================================================="
        echo "SSH Connection Failed. Modern Raspberry Pi OS images no longer have a "
        echo "default 'pi' user. If you haven't created a user yet, please use the"
        echo "./prepare_sd_card.sh script to mount your SD card and initialize a user."
        echo "Or pass the user as an argument: ./find_rpi.sh <username>"
        echo "========================================================================="
    fi
else
    echo "Could not determine Raspberry Pi IP."
    return 1 2>/dev/null || kill -INT $$
fi
