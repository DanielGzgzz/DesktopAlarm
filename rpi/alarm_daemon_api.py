import logging
import json
from flask import Flask, request, jsonify
from datetime import datetime

# Setup Silent Local Logger
logger = logging.getLogger("alarm_daemon")
logger.setLevel(logging.INFO)
file_handler = logging.FileHandler("alarm.log")
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(file_handler)

app = Flask(__name__)
# In-memory store for alarms (can be extended to a file or sqlite later)
# Assuming single alarm for now
alarm_state = {
    "time": None, # e.g. "07:00"
    "enabled": False
}

@app.route("/api/alarm", methods=["GET"])
def get_alarm():
    return jsonify(alarm_state), 200

@app.route("/api/alarm", methods=["POST"])
def set_alarm():
    data = request.json
    if not data or "time" not in data:
        return jsonify({"error": "Invalid payload"}), 400

    alarm_state["time"] = data["time"]
    alarm_state["enabled"] = data.get("enabled", True)
    logger.info(f"Alarm set for {alarm_state['time']}, enabled={alarm_state['enabled']}")
    return jsonify({"message": "Alarm updated successfully", "state": alarm_state}), 200

@app.route("/api/logs", methods=["GET"])
def get_logs():
    try:
        with open("alarm.log", "r") as f:
            lines = f.readlines()
        # Return last 100 lines
        return jsonify({"logs": lines[-100:]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def run_server(port=5000):
    logger.info("Starting Alarm API Server...")
    app.run(host="0.0.0.0", port=port, use_reloader=False)

if __name__ == "__main__":
    run_server()
