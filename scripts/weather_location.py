"""Bounded, no-follow access to OmaDeck's Omarchy weather location file."""

from __future__ import annotations

import hashlib
import json
import math
import os
import stat
from pathlib import Path
from typing import Any


UID = os.getuid()
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
FILE_FLAGS = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
MAX_LOCATION_BYTES = 64 * 1024


def _open_parent(path: str) -> tuple[int, str]:
    if not os.path.isabs(path):
        raise ValueError("weather location path must be absolute")
    parts = Path(path).parts
    descriptor = os.open("/", DIRECTORY_FLAGS)
    try:
        for component in parts[1:-1]:
            next_descriptor = os.open(component, DIRECTORY_FLAGS, dir_fd=descriptor)
            metadata = os.fstat(next_descriptor)
            mode = stat.S_IMODE(metadata.st_mode)
            if metadata.st_uid not in (0, UID) or mode & 0o022:
                os.close(next_descriptor)
                raise PermissionError("unsafe weather location parent")
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor, parts[-1]
    except Exception:
        os.close(descriptor)
        raise


def _read_bounded(path: str) -> bytes:
    parent, name = _open_parent(path)
    try:
        descriptor = os.open(name, FILE_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)
    try:
        metadata = os.fstat(descriptor)
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_uid != UID
            or stat.S_IMODE(metadata.st_mode) & 0o022
            or metadata.st_size > MAX_LOCATION_BYTES
        ):
            raise PermissionError("unsafe weather location file")
        output = bytearray()
        while len(output) <= MAX_LOCATION_BYTES:
            chunk = os.read(descriptor, min(16384, MAX_LOCATION_BYTES - len(output) + 1))
            if not chunk:
                break
            output.extend(chunk)
        if len(output) > MAX_LOCATION_BYTES:
            raise ValueError("weather location file exceeds size limit")
        return bytes(output)
    finally:
        os.close(descriptor)


def _coordinate(value: Any, minimum: float, maximum: float) -> float | None:
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) and minimum <= number <= maximum else None


def read_location(path: str) -> dict[str, Any]:
    try:
        raw = _read_bounded(path)
        parsed = json.loads(raw)
        if not isinstance(parsed, dict):
            raise ValueError("weather location must be an object")
        name = parsed.get("name") if isinstance(parsed.get("name"), str) else ""
        return {
            "name": name.strip()[:80],
            "latitude": _coordinate(parsed.get("latitude"), -90, 90),
            "longitude": _coordinate(parsed.get("longitude"), -180, 180),
            "fingerprint": hashlib.sha256(raw).hexdigest(),
        }
    except (FileNotFoundError, NotADirectoryError):
        return {"name": "", "latitude": None, "longitude": None, "fingerprint": "missing"}
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return {"name": "", "latitude": None, "longitude": None, "fingerprint": "invalid"}
