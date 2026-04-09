import time
import threading
import numpy as np

# Try to import hardware modules, handle gracefully if not on Pi
try:
    from gpiozero import OutputDevice, Button
    gpio_available = True
except ImportError:
    gpio_available = False

try:
    import sounddevice as sd
    audio_available = True
except ImportError:
    audio_available = False

# Import logger
from alarm_daemon_api import logger

class HardwareController:
    def __init__(self, stop_callback=None):
        self.stop_callback = stop_callback

        if gpio_available:
            # Lamp on GPIO 17 (relay/outlet)
            self.lamp = OutputDevice(17)
            # Buzzer with transistor on GPIO 20
            self.buzzer = OutputDevice(20)
            # Button on GPIO 19
            self.button = Button(19, pull_up=True)
            self.button.when_pressed = self._on_button_press
            logger.info("Hardware initialized successfully via gpiozero")
        else:
            self.lamp = None
            self.buzzer = None
            self.button = None
            logger.warning("gpiozero not available, using mock hardware")

        # Noise monitoring setup
        self.noise_monitoring_active = False
        self.noise_thread = None

    def lamp_on(self):
        if gpio_available:
            self.lamp.on()
        logger.info("Lamp turned ON")

    def lamp_off(self):
        if gpio_available:
            self.lamp.off()
        logger.info("Lamp turned OFF")

    def buzzer_on(self):
        if gpio_available:
            self.buzzer.on()
        logger.info("Buzzer turned ON")

    def buzzer_off(self):
        if gpio_available:
            self.buzzer.off()
        logger.info("Buzzer turned OFF")

    def _on_button_press(self):
        logger.info("Stop button pressed on GPIO 19")
        if self.stop_callback:
            self.stop_callback()

    # Noise detection thread
    def start_noise_monitoring(self, threshold=50, duration=1):
        if not audio_available:
            logger.warning("sounddevice not available, cannot start noise monitoring")
            return

        if self.noise_monitoring_active:
            return

        self.noise_monitoring_active = True
        self.noise_thread = threading.Thread(
            target=self._noise_monitor_loop,
            args=(threshold, duration),
            daemon=True
        )
        self.noise_thread.start()
        logger.info("Noise monitoring started")

    def stop_noise_monitoring(self):
        self.noise_monitoring_active = False
        if self.noise_thread:
            self.noise_thread.join(timeout=2)
        logger.info("Noise monitoring stopped")

    def _noise_monitor_loop(self, threshold, duration):
        def audio_callback(indata, frames, time_info, status):
            if status:
                logger.debug(f"Audio status: {status}")
            # Calculate RMS as volume metric
            volume = np.linalg.norm(indata) * 10
            if volume > threshold:
                logger.info(f"Noise detected! Volume level: {volume:.2f}")

        try:
            with sd.InputStream(callback=audio_callback):
                while self.noise_monitoring_active:
                    time.sleep(1)
        except Exception as e:
            logger.error(f"Error in noise monitoring: {e}")

if __name__ == "__main__":
    hw = HardwareController()
