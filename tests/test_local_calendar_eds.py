"""Pure contract tests for EDS occurrence normalisation."""

from datetime import datetime, timezone
import importlib.util
import os
from pathlib import Path
import time
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/bin/local_calendar_eds.py"
SPEC = importlib.util.spec_from_file_location("local_calendar_eds_test", MODULE_PATH)
EDS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EDS)


class FakeText:
    def __init__(self, value):
        self.value = value

    def get_value(self):
        return self.value


class FakeComponent:
    def __init__(self, uid="series", title="Stand-up", status="confirmed"):
        self.uid = uid
        self.title = title
        self.status = status

    def get_uid(self):
        return self.uid

    def get_status(self):
        return self.status

    def dup_summary_for_locale(self, _locale):
        return FakeText(self.title)


class FakeECal:
    class Component:
        @staticmethod
        def new_from_icalcomponent(component):
            return component


class FakeICal:
    class PropertyStatus:
        CANCELLED = "cancelled"


class FakeTime:
    def __init__(self, *, epoch=None, year=2026, month=10, day=10, is_date=False):
        self.epoch = epoch
        self.year = year
        self.month = month
        self.day = day
        self.date_value = is_date

    def is_date(self):
        return self.date_value

    def get_year(self):
        return self.year

    def get_month(self):
        return self.month

    def get_day(self):
        return self.day

    def get_timezone(self):
        return object() if self.epoch is not None else None

    def as_timet_with_zone(self, _zone):
        return self.epoch

    def as_timet(self):
        return self.epoch


class EDSNormalisationTest(unittest.TestCase):
    info = {
        "uid": "google-work",
        "name": "Work",
        "account": "person@example.com",
        "color": "#ff0000",
    }

    def normalise(self, component, start, end):
        return EDS._normalise_instance(
            component, start, end, self.info, FakeECal, FakeICal,
        )

    def test_all_day_end_is_converted_from_exclusive_to_inclusive(self):
        event = self.normalise(
            FakeComponent(),
            FakeTime(year=2026, month=10, day=10, is_date=True),
            FakeTime(year=2026, month=10, day=13, is_date=True),
        )

        self.assertTrue(event["allDay"])
        self.assertEqual(event["date"], "2026-10-10")
        self.assertEqual(event["endDate"], "2026-10-12")
        self.assertEqual(event["time"], "")

    def test_cancelled_occurrence_is_omitted(self):
        event = self.normalise(
            FakeComponent(status="cancelled"),
            FakeTime(year=2026, month=10, day=10, is_date=True),
            FakeTime(year=2026, month=10, day=11, is_date=True),
        )
        self.assertIsNone(event)

    def test_recurring_occurrences_have_stable_distinct_ids(self):
        old_tz = os.environ.get("TZ")
        os.environ["TZ"] = "Europe/Lisbon"
        time.tzset()
        try:
            first_epoch = int(datetime(2026, 3, 22, 9, tzinfo=timezone.utc).timestamp())
            second_epoch = int(datetime(2026, 3, 29, 9, tzinfo=timezone.utc).timestamp())
            first = self.normalise(
                FakeComponent(), FakeTime(epoch=first_epoch), FakeTime(epoch=first_epoch + 3600),
            )
            second = self.normalise(
                FakeComponent(), FakeTime(epoch=second_epoch), FakeTime(epoch=second_epoch + 3600),
            )
        finally:
            if old_tz is None:
                os.environ.pop("TZ", None)
            else:
                os.environ["TZ"] = old_tz
            time.tzset()

        self.assertNotEqual(first["occurrenceId"], second["occurrenceId"])
        self.assertTrue(first["occurrenceId"].endswith(str(first_epoch)))
        self.assertEqual(first["time"], "09:00")
        self.assertEqual(second["time"], "10:00")


if __name__ == "__main__":
    unittest.main()
