import urllib.request
import json
import cmd

class SmartAlarmConsole(cmd.Cmd):
    intro = "Welcome to the Smart Alarm Console. Type help or ? to list commands.\n"
    prompt = "(alarm) "

    def __init__(self, rpi_ip, port=5000):
        super().__init__()
        self.base_url = f"http://{rpi_ip}:{port}/api"

    def _get(self, endpoint):
        try:
            req = urllib.request.Request(f"{self.base_url}/{endpoint}")
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode())
        except Exception as e:
            print(f"Error connecting to RPi: {e}")
            return None

    def _post(self, endpoint, data):
        try:
            req = urllib.request.Request(
                f"{self.base_url}/{endpoint}",
                data=json.dumps(data).encode(),
                headers={'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode())
        except Exception as e:
            print(f"Error connecting to RPi: {e}")
            return None

    def do_status(self, arg):
        """Get current alarm status."""
        data = self._get("alarm")
        if data:
            print(f"Current Alarm: {data.get('time', 'Not set')} | Enabled: {data.get('enabled')}")

    def do_set(self, arg):
        """Set a new alarm. Format: set HH:MM (e.g. set 07:30)"""
        if not arg or len(arg.split(':')) != 2:
            print("Invalid format. Use: set HH:MM (24-hour format)")
            return

        data = self._post("alarm", {"time": arg, "enabled": True})
        if data:
            print(f"Success: {data.get('message')}")

    def do_disable(self, arg):
        """Disable the current alarm."""
        # Need current time to send back
        current = self._get("alarm")
        if not current or not current.get("time"):
            print("No alarm currently set.")
            return

        data = self._post("alarm", {"time": current["time"], "enabled": False})
        if data:
            print("Alarm disabled.")

    def do_logs(self, arg):
        """Fetch and display recent logs from the RPi."""
        data = self._get("logs")
        if data and "logs" in data:
            print("--- RPi Logs ---")
            for line in data["logs"]:
                print(line.strip())
            print("----------------")
        elif data and "error" in data:
            print(f"Error reading logs: {data['error']}")

    def do_sync_calendar(self, arg):
        """[FUTURE] Sync alarms with a specific Google Calendar."""
        print("Google Calendar sync is not yet implemented.")
        print("To implement: Add OAuth2 flow here and fetch events for 'specific calendar',")
        print("then call the set_alarm endpoint with the earliest event time minus buffer.")

    def do_exit(self, arg):
        """Exit the console."""
        print("Goodbye!")
        return True

if __name__ == '__main__':
    import sys
    ip = "127.0.0.1" # default to local for testing
    if len(sys.argv) > 1:
        ip = sys.argv[1]
    else:
        print("Usage: python3 console.py <RPI_IP_ADDRESS>")
        print("Defaulting to 127.0.0.1 for local testing...\n")

    SmartAlarmConsole(ip).cmdloop()
