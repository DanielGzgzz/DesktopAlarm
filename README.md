# Desktop Alarm

A smart, network-connected alarm system utilizing a desktop application to interface with a Raspberry Pi (running DietPi).

## System Capabilities & Hardware
The `rpi/` folder contains the alarm daemon which implements all requested functionality, including:

- **GPIO Zero Automation:**
  - Lamp/Relay: **GPIO 17** (Turns on exactly at the alarm time)
  - Transistor Buzzer: **GPIO 20** (Triggers dynamically based on the decision tree)
  - Stop Button: **GPIO 19** (Halts the alarm entirely and resets the system)
- **Computer Vision (YOLO/OpenCV):**
  - Triggers 30 seconds after the lamp turns on.
  - Detects if a person is present.
- **Decision Tree:**
  - If a person is detected, starts the buzzer sequence.
  - The buzzer starts slowly (beeping with 10s intervals) and gets progressively faster.
- **Noise Detection:**
  - Background audio monitoring via `sounddevice`/`numpy` to silently log sudden loud noises to the local `alarm.log`.
- **API Server:**
  - A Flask REST API used by the Desktop Console to configure the alarm scheduling.

## Installation via SSH

Yes! The included `desktop/find_rpi.sh` script handles everything. You do not need to manually move files to the DietPi or manually install dependencies.

When you run `desktop/find_rpi.sh` on your Ubuntu machine, it will:
1. Search your network for the Raspberry Pi.
2. Filter out IPv6 and Router addresses to safely identify the correct host.
3. Automatically log in using the `root` / `root` credentials.
4. Copy the entire `rpi/` app directory to the device via SCP.
5. Remotely execute `apt-get` and `pip` installations via SSH to install all required libraries (Flask, OpenCV, Numpy, Sounddevice, GPIO Zero).
6. Automatically start the main background daemon so the alarm is immediately armed and listening.

## Usage

On your Ubuntu desktop:
```bash
cd desktop
./find_rpi.sh
./console.py <IP_ADDRESS>
```

In the interactive console:
- `set HH:MM` (e.g. `set 07:30`) sets the alarm time.
- `status` checks current alarm config.
- `logs` pulls down the silent event log from the Raspberry Pi.
