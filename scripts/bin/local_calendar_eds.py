"""Read-only Evolution Data Server adapter for ``local-calendar``.

The module deliberately imports PyGObject lazily.  The local calendar therefore
keeps working on machines where EDS is not installed or before a graphical
session has started its D-Bus services.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
import json
import os
from pathlib import Path
import tempfile
import time
from typing import Any


EXTERNAL_BACKENDS = {"caldav", "ews", "google", "microsoft365", "webdav"}


class EDSUnavailable(RuntimeError):
    """Raised when the EDS runtime cannot be reached."""


def state_path() -> Path:
    override = os.environ.get("LOCAL_CALENDAR_STATE_FILE")
    if override:
        return Path(override)
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return state_home / "debian-sway-dev/calendar/eds-status.json"


def _read_state() -> dict[str, Any]:
    try:
        value = json.loads(state_path().read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _write_state(value: dict[str, Any]) -> None:
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".eds-status.", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output, ensure_ascii=False, indent=2)
            output.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _fixture() -> dict[str, Any] | None:
    """Return an injected EDS snapshot used by the hermetic test suite."""
    path = os.environ.get("LOCAL_CALENDAR_EDS_FIXTURE")
    if not path:
        return None
    try:
        value = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise EDSUnavailable(f"could not read EDS fixture: {error}") from error
    if not isinstance(value, dict):
        raise EDSUnavailable("invalid EDS fixture")
    return value


def _imports():
    try:
        import gi

        gi.require_version("ECal", "2.0")
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ICalGLib", "3.0")
        from gi.repository import ECal, EDataServer, ICalGLib
    except (ImportError, ValueError) as error:
        raise EDSUnavailable(f"Evolution Data Server bindings unavailable: {error}") from error
    return ECal, EDataServer, ICalGLib


def _ancestors(registry, source) -> list[Any]:
    result = [source]
    seen = {source.get_uid()}
    parent_uid = source.get_parent()
    while parent_uid and parent_uid not in seen:
        parent = registry.ref_source(parent_uid)
        if parent is None:
            break
        result.append(parent)
        seen.add(parent_uid)
        parent_uid = parent.get_parent()
    return result


def _backend_name(source, extension_name: str) -> str:
    if not source.has_extension(extension_name):
        return ""
    extension = source.get_extension(extension_name)
    getter = getattr(extension, "get_backend_name", None)
    return (getter() if getter else "") or ""


def _source_info(registry, source, EDataServer) -> dict[str, Any] | None:
    chain = _ancestors(registry, source)
    calendar_backend = _backend_name(source, EDataServer.SOURCE_EXTENSION_CALENDAR)
    collection_backend = ""
    collection_uid = ""
    account = ""
    has_goa = False
    for ancestor in chain:
        if ancestor.has_extension(EDataServer.SOURCE_EXTENSION_GOA):
            has_goa = True
            account = ancestor.get_display_name() or account
        backend = _backend_name(ancestor, EDataServer.SOURCE_EXTENSION_COLLECTION)
        if backend:
            collection_backend = backend
            collection_uid = ancestor.get_uid()
            account = ancestor.get_display_name() or account

    backends = {calendar_backend.casefold(), collection_backend.casefold()}
    if not has_goa and not (backends & EXTERNAL_BACKENDS):
        return None

    selectable = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
    color_getter = getattr(selectable, "get_color", None)
    color = (color_getter() if color_getter else "") or "#89b4fa"
    backend = collection_backend or calendar_backend or "online"
    return {
        "uid": source.get_uid(),
        "name": source.get_display_name() or "Calendar",
        "account": account or backend,
        "backend": backend,
        "color": color,
        "_refreshUid": collection_uid or source.get_uid(),
    }


def _public_info(info: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in info.items() if not key.startswith("_")}


def _registry_sources():
    ECal, EDataServer, ICalGLib = _imports()
    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
        enabled = registry.list_enabled(EDataServer.SOURCE_EXTENSION_CALENDAR)
    except Exception as error:
        raise EDSUnavailable(f"could not open Evolution Data Server: {error}") from error
    sources = []
    for source in enabled:
        selectable = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
        selected_getter = getattr(selectable, "get_selected", None)
        if selected_getter is not None and not selected_getter():
            continue
        info = _source_info(registry, source, EDataServer)
        if info:
            sources.append((source, info))
    return ECal, EDataServer, ICalGLib, registry, sources


def _summary(component) -> str:
    text = component.dup_summary_for_locale(None)
    return (text.get_value() if text else "") or "(Untitled event)"


def _local_datetime(value) -> datetime:
    """Convert an ICalGLib.Time occurrence to the desktop's local timezone."""
    zone = value.get_timezone()
    timestamp = value.as_timet_with_zone(zone) if zone is not None else value.as_timet()
    return datetime.fromtimestamp(timestamp).astimezone()


def _connect_calendar(ECal, source):
    client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 10, None)
    local_zone = ECal.util_get_system_timezone()
    if local_zone is not None:
        client.set_default_timezone(local_zone)
    return client


def _normalise_instance(icalcomp, start, end, info, ECal, ICalGLib) -> dict[str, Any] | None:
    component = ECal.Component.new_from_icalcomponent(icalcomp)
    if component.get_status() == ICalGLib.PropertyStatus.CANCELLED:
        return None

    uid = component.get_uid() or "missing-uid"
    all_day = bool(start.is_date())
    if all_day:
        starts = date(start.get_year(), start.get_month(), start.get_day())
        exclusive_end = date(end.get_year(), end.get_month(), end.get_day())
        inclusive_end = max(starts, exclusive_end - timedelta(days=1))
        start_time = ""
        end_time = ""
        occurrence = starts.isoformat()
    else:
        local_start = _local_datetime(start)
        local_end = _local_datetime(end)
        starts = local_start.date()
        inclusive_end = local_end.date()
        start_time = local_start.strftime("%H:%M")
        end_time = local_end.strftime("%H:%M")
        # Epoch seconds keep a recurrence occurrence stable even if the local
        # timezone setting changes later.
        occurrence = str(int(local_start.timestamp()))

    occurrence_id = f'eds:{info["uid"]}:{uid}:{occurrence}'
    return {
        "id": occurrence_id,
        "occurrenceId": occurrence_id,
        "title": _summary(component),
        "date": starts.isoformat(),
        "time": start_time,
        "endDate": inclusive_end.isoformat(),
        "endTime": end_time,
        "allDay": all_day,
        "source": info["account"],
        "calendar": info["name"],
        "color": info["color"],
        "readOnly": True,
        "reminder": -1,
    }


def _overlaps(event: dict[str, Any], start_date: str, end_date: str) -> bool:
    event_start = str(event.get("date", ""))
    event_end = str(event.get("endDate") or event_start)
    if (not event.get("allDay") and event.get("endTime") == "00:00"
            and event_end > event_start):
        event_end = (date.fromisoformat(event_end) - timedelta(days=1)).isoformat()
    return event_start < end_date and event_end >= start_date


def _events_in_range(events, start_date: str, end_date: str) -> list[dict[str, Any]]:
    return [event for event in events
            if isinstance(event, dict) and _overlaps(event, start_date, end_date)]


def list_events(start_date: str, end_date: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[str]]:
    fixture = _fixture()
    if fixture is not None:
        events = _events_in_range(fixture.get("events", []), start_date, end_date)
        return events, fixture.get("sources", []), fixture.get("errors", [])

    ECal, _EDataServer, ICalGLib, _registry, sources = _registry_sources()
    range_start = int(datetime.fromisoformat(start_date).astimezone().timestamp())
    range_end = int(datetime.fromisoformat(end_date).astimezone().timestamp())
    events: list[dict[str, Any]] = []
    errors: list[str] = []
    source_status: list[dict[str, Any]] = []

    for source, info in sources:
        current = _public_info(info)
        try:
            client = _connect_calendar(ECal, source)

            def collect(icalcomp, instance_start, instance_end, *_unused):
                event = _normalise_instance(
                    icalcomp, instance_start, instance_end, info, ECal, ICalGLib,
                )
                if event is not None:
                    events.append(event)
                return True

            client.generate_instances_sync(range_start, range_end, None, collect)
            current["available"] = True
        except Exception as error:
            message = f'{info["name"]}: {error}'
            current.update(available=False, error=str(error))
            errors.append(message)
        source_status.append(current)
    previous = _read_state()
    _write_state({
        "available": True,
        "lastAttempt": previous.get("lastAttempt"),
        "lastSync": previous.get("lastSync"),
        "sources": source_status,
        "errors": errors,
    })
    return _events_in_range(events, start_date, end_date), source_status, errors


def sync() -> dict[str, Any]:
    fixture = _fixture()
    if fixture is not None:
        result = {
            "available": True,
            "lastAttempt": int(time.time()),
            "lastSync": int(time.time()) if not fixture.get("errors") else _read_state().get("lastSync"),
            "sources": fixture.get("sources", []),
            "errors": fixture.get("errors", []),
        }
        _write_state(result)
        return result

    attempted = int(time.time())
    try:
        ECal, _EDataServer, _ICalGLib, registry, sources = _registry_sources()
    except EDSUnavailable as error:
        previous = _read_state()
        result = {
            "available": False,
            "lastAttempt": attempted,
            "lastSync": previous.get("lastSync"),
            "sources": previous.get("sources", []),
            "errors": [str(error)],
        }
        _write_state(result)
        return result

    errors = []
    statuses = []
    refreshed: set[str] = set()
    for source, info in sources:
        current = _public_info(info)
        try:
            uid = info["_refreshUid"]
            if uid not in refreshed:
                registry.refresh_backend_sync(uid, None)
                refreshed.add(uid)
            client = _connect_calendar(ECal, source)
            if client.check_refresh_supported():
                client.refresh_sync(None)
            current["available"] = True
        except Exception as error:
            current.update(available=False, error=str(error))
            errors.append(f'{info["name"]}: {error}')
        statuses.append(current)
    result = {
        "available": True,
        "lastAttempt": attempted,
        "lastSync": attempted if not errors else _read_state().get("lastSync"),
        "sources": statuses,
        "errors": errors,
    }
    _write_state(result)
    return result


def status() -> dict[str, Any]:
    fixture = _fixture()
    if fixture is not None:
        previous = _read_state()
        return {
            "available": True,
            "lastAttempt": previous.get("lastAttempt"),
            "lastSync": previous.get("lastSync"),
            "sources": fixture.get("sources", []),
            "errors": fixture.get("errors", []),
        }

    previous = _read_state()
    try:
        _ECal, _EDS, _ICal, _registry, sources = _registry_sources()
        discovered = [_public_info(info) for _source, info in sources]
        return {
            "available": True,
            "lastAttempt": previous.get("lastAttempt"),
            "lastSync": previous.get("lastSync"),
            "sources": discovered,
            "errors": previous.get("errors", []),
        }
    except EDSUnavailable as error:
        return {
            "available": False,
            "lastAttempt": previous.get("lastAttempt"),
            "lastSync": previous.get("lastSync"),
            "sources": previous.get("sources", []),
            "errors": [str(error)],
        }
