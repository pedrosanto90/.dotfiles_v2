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
        self.state = Path(self.temp.name) / "eds-status.json"
        self.fixture = Path(self.temp.name) / "eds.json"
        self.fixture.write_text(json.dumps({"events": [], "sources": [], "errors": []}))
        self.env = dict(
            os.environ,
            LOCAL_CALENDAR_FILE=str(self.store),
            LOCAL_CALENDAR_STATE_FILE=str(self.state),
            LOCAL_CALENDAR_EDS_FIXTURE=str(self.fixture),
            TZ="Europe/Lisbon",
        )

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

    def use_eds_fixture(self, events=None, sources=None, errors=None):
        self.fixture.write_text(json.dumps({
            "events": events or [],
            "sources": sources or [],
            "errors": errors or [],
        }))
        return self.fixture

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

    def test_list_enriches_local_events_and_aggregates_external_occurrences(self):
        local = self.add(title="Local meeting", clock="09:00")
        self.use_eds_fixture(events=[{
            "id": "eds:google:remote-1:2026-10-10",
            "occurrenceId": "eds:google:remote-1:2026-10-10",
            "title": "Conference",
            "date": "2026-10-10",
            "time": "",
            "endDate": "2026-10-12",
            "endTime": "",
            "allDay": True,
            "source": "person@example.com",
            "calendar": "Work",
            "color": "#ff0000",
            "readOnly": True,
            "reminder": -1,
        }])

        listed = json.loads(self.run_calendar("list", "--month", "2026-10").stdout)

        self.assertEqual([event["title"] for event in listed], ["Conference", "Local meeting"])
        local_result = next(event for event in listed if event["id"] == local["id"])
        self.assertEqual(local_result["source"], "local")
        self.assertEqual(local_result["occurrenceId"], f'local:{local["id"]}')
        self.assertFalse(local_result["readOnly"])
        self.assertNotEqual(listed[0]["id"], local_result["id"])

    def test_multiday_all_day_occurrence_is_returned_for_each_covered_day(self):
        self.use_eds_fixture(events=[{
            "id": "eds:m365:series:2026-10-10",
            "occurrenceId": "eds:m365:series:2026-10-10",
            "title": "Company retreat",
            "date": "2026-10-10",
            "time": "",
            "endDate": "2026-10-12",
            "endTime": "",
            "allDay": True,
            "source": "Microsoft 365",
            "calendar": "Team",
            "color": "#0078d4",
            "readOnly": True,
            "reminder": -1,
        }])

        middle = json.loads(self.run_calendar("list", "--date", "2026-10-11").stdout)
        outside = json.loads(self.run_calendar("list", "--date", "2026-10-13").stdout)

        self.assertEqual([event["title"] for event in middle], ["Company retreat"])
        self.assertEqual(outside, [])

    def test_timed_event_ending_at_midnight_does_not_cover_the_next_day(self):
        self.use_eds_fixture(events=[{
            "id": "eds:google:overnight:1",
            "occurrenceId": "eds:google:overnight:1",
            "title": "Late shift", "date": "2026-10-10", "time": "22:00",
            "endDate": "2026-10-11", "endTime": "00:00", "allDay": False,
            "source": "Google", "calendar": "Work", "color": "#00aa00",
            "readOnly": True, "reminder": -1,
        }])

        start = json.loads(self.run_calendar("list", "--date", "2026-10-10").stdout)
        next_day = json.loads(self.run_calendar("list", "--date", "2026-10-11").stdout)

        self.assertEqual([event["title"] for event in start], ["Late shift"])
        self.assertEqual(next_day, [])

    def test_external_ids_are_never_accepted_by_write_operations(self):
        identifier = "eds:google:remote:2026-10-10T09:00:00+01:00"
        update = self.run_calendar(
            "update", identifier, "--title", "Changed", "--date", "2026-10-10",
            "--time", "10:00", "--reminder", "15", check=False,
        )
        delete = self.run_calendar("delete", identifier, check=False)

        self.assertNotEqual(update.returncode, 0)
        self.assertNotEqual(delete.returncode, 0)
        self.assertIn("read-only", update.stderr)
        self.assertIn("read-only", delete.stderr)

    def test_partial_sync_status_keeps_cached_fixture_and_local_events_visible(self):
        self.add(title="Offline-safe")
        source = {"uid": "outlook", "name": "Work", "account": "Outlook.com"}
        self.use_eds_fixture(events=[{
            "id": "eds:outlook:cached:2026-10-10T10:00:00+01:00",
            "occurrenceId": "eds:outlook:cached:2026-10-10T10:00:00+01:00",
            "title": "Cached event", "date": "2026-10-10", "time": "10:00",
            "endDate": "2026-10-10", "endTime": "11:00", "allDay": False,
            "source": "Outlook.com", "calendar": "Work", "color": "#0078d4",
            "readOnly": True, "reminder": -1,
        }], sources=[source], errors=["Work: authentication expired"])

        synced = json.loads(self.run_calendar("sync").stdout)
        status = json.loads(self.run_calendar("status").stdout)
        listed = json.loads(self.run_calendar("list", "--date", "2026-10-10").stdout)

        self.assertIsNone(synced["lastSync"])
        self.assertEqual(status["errors"], ["Work: authentication expired"])
        self.assertEqual({event["title"] for event in listed}, {"Offline-safe", "Cached event"})

    def test_unavailable_eds_does_not_hide_local_events(self):
        self.add(title="Still here")
        broken = Path(self.temp.name) / "broken-eds.json"
        broken.write_text("not json")
        self.env["LOCAL_CALENDAR_EDS_FIXTURE"] = str(broken)

        listed = json.loads(self.run_calendar("list", "--date", "2026-10-10").stdout)

        self.assertEqual([event["title"] for event in listed], ["Still here"])


if __name__ == "__main__":
    unittest.main()
