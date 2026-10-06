"""Test the local calendar store and reminder delivery state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/bin/local-calendar"


class LocalCalendarTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.store = Path(self.temp.name) / "events.json"
        self.env = dict(os.environ, LOCAL_CALENDAR_FILE=str(self.store), TZ="Europe/Lisbon")

    def run_calendar(self, *args, check=True):
        return subprocess.run(
            [str(SCRIPT), *args], env=self.env, capture_output=True,
            text=True, check=check,
        )

    def add(self, title="Dentist", date="2026-10-10", clock="14:30", reminder="15"):
        result = self.run_calendar(
            "add", "--title", title, "--date", date,
            "--time", clock, "--reminder", reminder,
        )
        return json.loads(result.stdout)

    def test_add_list_update_and_delete(self):
        event = self.add()
        listed = json.loads(self.run_calendar("list", "--month", "2026-10").stdout)
        self.assertEqual([item["title"] for item in listed], ["Dentist"])

        self.run_calendar(
            "update", event["id"], "--title", "Doctor",
            "--date", "2026-10-11", "--time", "09:00", "--reminder", "30",
        )
        day = json.loads(self.run_calendar("list", "--date", "2026-10-11").stdout)
        self.assertEqual(day[0]["title"], "Doctor")
        self.assertEqual(day[0]["reminder"], 30)

        self.run_calendar("delete", event["id"])
        self.assertEqual(json.loads(self.run_calendar("list", "--month", "2026-10").stdout), [])

    def test_due_marks_reminder_as_delivered_once(self):
        self.add()
        starts = int(time.mktime(time.strptime("2026-10-10 14:30", "%Y-%m-%d %H:%M")))
        first = json.loads(self.run_calendar("due", "--now", str(starts - 15 * 60)).stdout)
        second = json.loads(self.run_calendar("due", "--now", str(starts)).stdout)
        self.assertEqual(len(first), 1)
        self.assertEqual(second, [])

    def test_no_reminder_never_becomes_due(self):
        self.add(reminder="-1")
        starts = int(time.mktime(time.strptime("2026-10-10 14:30", "%Y-%m-%d %H:%M")))
        due = json.loads(self.run_calendar("due", "--now", str(starts)).stdout)
        self.assertEqual(due, [])

    def test_notify_uses_desktop_notification_and_sound(self):
        bin_dir = Path(self.temp.name) / "bin"
        bin_dir.mkdir()
        calls = Path(self.temp.name) / "calls"
        sound = Path(self.temp.name) / "alarm.oga"
        sound.touch()
        for name in ("notify-send", "pw-play"):
            command = bin_dir / name
            command.write_text(
                '#!/usr/bin/env bash\nprintf "%s %s\\n" "${0##*/}" "$*" >>"${CALENDAR_TEST_LOG}"\n'
            )
            command.chmod(0o755)
        self.env.update(
            PATH=f"{bin_dir}:/usr/bin:/bin",
            LOCAL_CALENDAR_SOUND=str(sound),
            CALENDAR_TEST_LOG=str(calls),
        )
        self.add(reminder="0")
        starts = int(time.mktime(time.strptime("2026-10-10 14:30", "%Y-%m-%d %H:%M")))

        result = self.run_calendar("notify", "--now", str(starts))

        self.assertEqual(result.returncode, 0)
        logged = calls.read_text().splitlines()
        self.assertTrue(any(line.startswith("notify-send ") for line in logged))
        self.assertTrue(any(line.startswith("pw-play ") for line in logged))

    def test_rejects_invalid_date_and_time(self):
        result = self.run_calendar(
            "add", "--title", "Broken", "--date", "2026-02-30",
            "--time", "25:00", "--reminder", "15", check=False,
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
