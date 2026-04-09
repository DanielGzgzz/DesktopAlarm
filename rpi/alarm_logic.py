import time
import threading

try:
    import cv2
    cv2_available = True
except ImportError:
    cv2_available = False

from alarm_daemon_api import logger

class CameraDetector:
    def __init__(self, yolo_weights=None, yolo_config=None, coco_names=None):
        self.active = False
        self.cv2_available = cv2_available

        if self.cv2_available and yolo_weights and yolo_config and coco_names:
            try:
                self.net = cv2.dnn.readNet(yolo_weights, yolo_config)
                with open(coco_names, "r") as f:
                    self.classes = [line.strip() for line in f.readlines()]
                self.layer_names = self.net.getLayerNames()
                self.output_layers = [self.layer_names[i - 1] for i in self.net.getUnconnectedOutLayers()]
                logger.info("YOLO network loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load YOLO: {e}")
                self.net = None
        else:
            self.net = None
            logger.warning("Running without actual YOLO model (mocking detection)")

    def detect_person(self):
        """Returns True if a person is detected in the current camera frame."""
        if not self.cv2_available or self.net is None:
            # Mock detection: randomly return True for testing if no model is loaded
            logger.info("Mock camera: returning True for person detection")
            return True

        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            logger.error("Could not open camera")
            return False

        ret, frame = cap.read()
        cap.release()
        if not ret:
            logger.error("Could not read frame from camera")
            return False

        height, width, channels = frame.shape
        blob = cv2.dnn.blobFromImage(frame, 0.00392, (416, 416), (0, 0, 0), True, crop=False)
        self.net.setInput(blob)
        outs = self.net.forward(self.output_layers)

        for out in outs:
            for detection in out:
                scores = detection[5:]
                class_id = scores.argmax()
                confidence = scores[class_id]

                # Check if detected object is 'person' (usually class_id 0 in COCO) and confident
                if confidence > 0.5 and self.classes[class_id] == "person":
                    logger.info("Person detected by camera!")
                    return True

        logger.info("No person detected")
        return False


class AlarmLogic:
    def __init__(self, hardware):
        self.hardware = hardware
        self.camera = CameraDetector()

        self.alarm_active = False
        self.sequence_thread = None

    def start_alarm_sequence(self):
        """Starts the main alarm sequence (light -> 30s -> camera -> buzzer)."""
        if self.alarm_active:
            return

        self.alarm_active = True
        self.sequence_thread = threading.Thread(target=self._sequence_loop, daemon=True)
        self.sequence_thread.start()

    def stop_alarm(self):
        """Called when stop button is pressed or requested via API."""
        self.alarm_active = False
        self.hardware.lamp_off()
        self.hardware.buzzer_off()
        logger.info("Alarm stopped, putting system to sleep.")

    def _sequence_loop(self):
        logger.info("Starting alarm sequence")

        # 1. Turn on lamp
        self.hardware.lamp_on()

        # 2. Wait 30 seconds (checking for cancellation)
        logger.info("Waiting 30 seconds before buzzing...")
        for _ in range(30):
            if not self.alarm_active:
                return
            time.sleep(1)

        # 3. Use Camera to check for person
        if not self.alarm_active:
            return

        person_detected = self.camera.detect_person()

        # 4. Decision Tree
        if person_detected:
            logger.info("Decision Tree: Person detected -> starting buzzer sequence")
            self._buzzer_sequence()
        else:
            logger.info("Decision Tree: No person detected -> going to sleep")
            self.stop_alarm()

    def _buzzer_sequence(self):
        # Buzzing starts slowly with intervals up to 10s, decreasing
        intervals = [10, 8, 6, 4, 2, 1, 1, 1]
        interval_idx = 0

        while self.alarm_active:
            self.hardware.buzzer_on()
            time.sleep(0.5) # short beep
            self.hardware.buzzer_off()

            # Wait for the current interval
            current_interval = intervals[interval_idx]
            for _ in range(int(current_interval * 10)): # 0.1s steps for responsiveness
                if not self.alarm_active:
                    break
                time.sleep(0.1)

            # Decrease interval to make it buzz faster over time
            if interval_idx < len(intervals) - 1:
                interval_idx += 1
