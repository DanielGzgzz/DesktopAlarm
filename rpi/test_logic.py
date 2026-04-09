import unittest
from unittest.mock import MagicMock
import sys
import os

# Add rpi folder to path to import logic
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from alarm_logic import AlarmLogic
from hardware import HardwareController

class TestLogic(unittest.TestCase):
    def test_decision_tree_person_detected(self):
        # Mock hardware
        hw = MagicMock(spec=HardwareController)
        logic = AlarmLogic(hw)

        # Mock camera to always detect person
        logic.camera.detect_person = MagicMock(return_value=True)

        # Prevent the actual buzzer loop from blocking forever during test
        # We just want to ensure it calls _buzzer_sequence
        logic._buzzer_sequence = MagicMock()

        # Override the time.sleep to run instantly
        with unittest.mock.patch('time.sleep', return_value=None):
            logic.alarm_active = True
            logic._sequence_loop()

            # Verify sequence
            hw.lamp_on.assert_called_once()
            logic.camera.detect_person.assert_called_once()
            logic._buzzer_sequence.assert_called_once()

    def test_decision_tree_no_person(self):
        # Mock hardware
        hw = MagicMock(spec=HardwareController)
        logic = AlarmLogic(hw)

        # Mock camera to NOT detect person
        logic.camera.detect_person = MagicMock(return_value=False)

        logic._buzzer_sequence = MagicMock()
        logic.stop_alarm = MagicMock()

        # Override time.sleep
        with unittest.mock.patch('time.sleep', return_value=None):
            logic.alarm_active = True
            logic._sequence_loop()

            # Verify sequence
            hw.lamp_on.assert_called_once()
            logic.camera.detect_person.assert_called_once()
            logic._buzzer_sequence.assert_not_called()
            logic.stop_alarm.assert_called_once()

if __name__ == '__main__':
    unittest.main()
