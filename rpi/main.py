import time
import threading
from datetime import datetime

try:
    from apscheduler.schedulers.background import BackgroundScheduler
    scheduler_available = True
except ImportError:
    scheduler_available = False

from alarm_daemon_api import app, run_server, alarm_state, logger
from hardware import HardwareController
from alarm_logic import AlarmLogic

# Initialize Hardware and Logic
hardware = HardwareController()
logic = AlarmLogic(hardware)

# Hook up the stop button callback to the logic
hardware.stop_callback = logic.stop_alarm

# Start noise monitoring in background
hardware.start_noise_monitoring()

def check_alarm_time():
    """Timer callback to check if the current time matches the alarm time."""
    if not alarm_state["enabled"] or not alarm_state["time"]:
        return

    now = datetime.now().strftime("%H:%M")
    if now == alarm_state["time"] and not logic.alarm_active:
        logger.info(f"Alarm triggered at {now}")
        logic.start_alarm_sequence()
        # Disable alarm to prevent re-triggering in the same minute
        alarm_state["enabled"] = False

if __name__ == "__main__":
    if scheduler_available:
        scheduler = BackgroundScheduler()
        # Check alarm every 10 seconds
        scheduler.add_job(check_alarm_time, 'interval', seconds=10)
        scheduler.start()
        logger.info("Scheduler started")
    else:
        logger.warning("apscheduler not installed, using simple thread loop for timer")
        def simple_loop():
            while True:
                check_alarm_time()
                time.sleep(10)
        t = threading.Thread(target=simple_loop, daemon=True)
        t.start()

    # Start Flask API server (blocks until exited)
    try:
        run_server(port=5000)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        logic.stop_alarm()
        hardware.stop_noise_monitoring()
        if scheduler_available:
            scheduler.shutdown()
