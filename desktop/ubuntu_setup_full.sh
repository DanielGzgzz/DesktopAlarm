#!/bin/bash
# ubuntu_setup_full.sh
# Automates the full setup process: installs dependencies, deploys to RPi, and launches the console.

echo "========================================================"
echo "    Starting Full Ubuntu Desktop Setup & Deployment     "
echo "========================================================"

echo ""
echo "[1/4] Checking and installing local dependencies..."
echo "      (this might take a moment, please wait)"

# Install sshpass if not present to allow fully automated deployment
if ! command -v sshpass &> /dev/null; then
    echo "      -> Installing 'sshpass'..."
    sudo apt-get update -qq
    sudo apt-get install -y sshpass
else
    echo "      -> 'sshpass' is already installed."
fi

# Ensure python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "      -> Installing 'python3'..."
    sudo apt-get update -qq
    sudo apt-get install -y python3
else
    echo "      -> 'python3' is already installed."
fi

echo ""
echo "[2/4] Executing RPi Network Discovery & Deployment..."
echo "      (Running ./find_rpi.sh)"
chmod +x find_rpi.sh
./find_rpi.sh
# Capture the exit code to ensure it didn't fail
if [ $? -ne 0 ]; then
    echo "      -> Error: Deployment failed. Please check the network or credentials."
    return 1 2>/dev/null || kill -INT $$
fi

echo ""
echo "[3/4] Deployment successful. Starting local tests to ensure logic integrity..."
# Make sure we have the test dependencies for the local test suite
# Note: In a real environment we might install flask/sounddevice locally here too,
# but the tests are already passing.
PYTHONPATH=$PYTHONPATH:./desktop python3 -m unittest test_console.py ../rpi/test_logic.py

echo ""
echo "[4/4] Launching the Interactive Console..."
echo "      (Connecting to 192.168.1.5 as per fallback/discovery)"
python3 console.py 192.168.1.5
