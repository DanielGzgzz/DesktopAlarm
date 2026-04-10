#!/bin/bash
# find_rpi.sh
# Scans the local network to find the Raspberry Pi, copies the alarm code, and executes it.

RPI_USER="root"
RPI_PASS="root"

echo "Attempting to find DietPi via mDNS (dietpi.local)..."
RPI_IP=$(ping -c 1 dietpi.local 2>/dev/null | awk -F'[()]' '/PING/{print $2}')

if [ -z "$RPI_IP" ]; then
    echo "mDNS failed. Attempting direct fallback to 192.168.1.5..."
    ping -c 1 -W 1 192.168.1.5 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        RPI_IP="192.168.1.5"
        echo "Found device at 192.168.1.5."
    else
        echo "Direct fallback failed. Falling back to ARP scan..."

        # We must ping the broadcast or common IPs to populate the ARP cache
        SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
        if [ -n "$SUBNET" ]; then
            echo "Pinging subnet $SUBNET to populate ARP cache (this takes a few seconds)..."
            BASE_IP=$(echo $SUBNET | awk -F. '{print $1"."$2"."$3}')
            for i in {1..20}; do
                ping -c 1 -W 1 $BASE_IP.$i >/dev/null 2>&1 &
            done
            wait
        fi

        MAP_OUT=$(ip -4 neigh | awk '/REACHABLE|STALE/{print $1}')

        if [ -n "$MAP_OUT" ]; then
            IFS=$'\n' read -r -d '' -a IP_ARRAY <<< "$MAP_OUT"

            FILTERED_IPS=()
            for ip in "${IP_ARRAY[@]}"; do
                if [[ ! "$ip" =~ \.1$ ]] && [[ ! "$ip" =~ \.254$ ]]; then
                    FILTERED_IPS+=("$ip")
                fi
            done

            if [ ${#FILTERED_IPS[@]} -eq 1 ]; then
                RPI_IP="${FILTERED_IPS[0]}"
                echo "Found one potential SSH server at $RPI_IP"
            elif [ ${#FILTERED_IPS[@]} -gt 1 ]; then
                echo "Multiple servers found. Please select the DietPi:"
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

        if [ -z "$RPI_IP" ]; then
            echo "ARP scan failed to find unique IPs."
            echo "Assuming 192.168.1.5 anyway as per final fallback."
            RPI_IP="192.168.1.5"
        fi
    fi
fi

if [ -n "$RPI_IP" ]; then
    echo "Connecting to $RPI_USER@$RPI_IP to install desktop alarm..."

    if command -v sshpass &> /dev/null; then
        echo "sshpass detected. Automating installation."
        sshpass -p "$RPI_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ../rpi $RPI_USER@$RPI_IP:/root/

        echo "Installing dependencies on target and starting..."
        sshpass -p "$RPI_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $RPI_USER@$RPI_IP << 'REMOTE'
            apt-get update && apt-get install -y python3-pip python3-flask python3-gpiozero python3-sounddevice python3-numpy python3-opencv
            pip3 install apscheduler flask gpiozero sounddevice numpy opencv-python --break-system-packages 2>/dev/null || true
            cd /root/rpi
            bash -c "python3 main.py > daemon.log 2>&1 &"
            echo "Daemon started."
REMOTE
    else
        echo "sshpass not found. Please enter password ($RPI_PASS) when prompted."
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r ../rpi $RPI_USER@$RPI_IP:/root/

        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $RPI_USER@$RPI_IP << 'REMOTE'
            apt-get update && apt-get install -y python3-pip python3-flask python3-gpiozero python3-sounddevice python3-numpy python3-opencv
            pip3 install apscheduler flask gpiozero sounddevice numpy opencv-python --break-system-packages 2>/dev/null || true
            cd /root/rpi
            bash -c "python3 main.py > daemon.log 2>&1 &"
            echo "Daemon started."
REMOTE
    fi
    echo "========================================================================="
    echo "Installation complete. The rpi daemon should be running on the DietPi."
    echo "Use ./console.py $RPI_IP to interact with it."
    echo "========================================================================="
else
    echo "Could not determine IP."
    return 1 2>/dev/null || kill -INT $$
fi
