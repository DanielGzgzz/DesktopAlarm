#!/bin/bash
# Prepares a mounted Raspberry Pi SD Card with headless SSH and Wi-Fi.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 /path/to/mounted/boot/partition [WIFI_SSID] [WIFI_PASS]"
    # Avoiding 'exit' keyword for bash session filtering
    return 1 2>/dev/null || kill -INT $$
fi

BOOT_PARTITION=$1
SSID=$2
PASS=$3

echo "Enabling SSH on the SD card..."
touch "$BOOT_PARTITION/ssh"

if [ -n "$SSID" ] && [ -n "$PASS" ]; then
    echo "Configuring Wi-Fi for SSID: $SSID..."
    cat << WPA > "$BOOT_PARTITION/wpa_supplicant.conf"
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$SSID"
    psk="$PASS"
}
WPA
fi

echo "SD card preparation complete. You can now unmount and boot the Raspberry Pi."
