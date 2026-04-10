#!/bin/bash
# Prepares a mounted Raspberry Pi SD Card with headless SSH, Wi-Fi, and user initialization.

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 /path/to/mounted/boot/partition [WIFI_SSID] [WIFI_PASS] [RPI_USER] [RPI_PASS]"
    return 1 2>/dev/null || kill -INT $$
fi

BOOT_PARTITION=$1
SSID=$2
PASS=$3
RPI_USER=${4:-admin}
RPI_PASS=${5:-test1234}

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

echo "Initializing user account: $RPI_USER..."
# Raspberry Pi OS requires userconf.txt for headless user initialization since the default 'pi' user was removed
# Encrypt the password using openssl
ENCRYPTED_PASS=$(echo "$RPI_PASS" | openssl passwd -6 -stdin)
echo "$RPI_USER:$ENCRYPTED_PASS" > "$BOOT_PARTITION/userconf.txt"

echo "SD card preparation complete. You can now unmount and boot the Raspberry Pi."
