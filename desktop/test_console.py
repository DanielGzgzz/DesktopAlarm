import unittest
from unittest.mock import patch
from console import SmartAlarmConsole

class TestConsole(unittest.TestCase):
    @patch('console.SmartAlarmConsole._post')
    def test_set_alarm(self, mock_post):
        mock_post.return_value = {"message": "Alarm updated successfully"}
        console = SmartAlarmConsole("127.0.0.1")
        console.do_set("08:00")
        mock_post.assert_called_with("alarm", {"time": "08:00", "enabled": True})

    @patch('console.SmartAlarmConsole._get')
    def test_get_logs(self, mock_get):
        mock_get.return_value = {"logs": ["Log line 1", "Log line 2"]}
        console = SmartAlarmConsole("127.0.0.1")
        # Just ensure it doesn't crash when printing
        console.do_logs("")
        mock_get.assert_called_with("logs")

if __name__ == '__main__':
    unittest.main()
