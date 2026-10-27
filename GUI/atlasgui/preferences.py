"""Where the GUI keeps what the user chose: settings and colour themes.

Two stores, found in one place:

* the **settings** -- theme, text size, and whatever later pages add -- in the
  platform's own store, through QSettings (a plist on macOS, an INI file on
  Linux, the registry on Windows);
* the **colour themes** the user made, one JSON file each in
  ``<config>/ATLAS/themes/``, so that a theme can be handed to a colleague or
  kept with a project.  ``<config>`` is ``~/.config`` on Linux and
  ``~/Library/Preferences`` on macOS.

No widgets here: the store can be read and written headlessly.
"""

from __future__ import annotations

import json
import os
import re

from PyQt6.QtCore import QSettings, QStandardPaths

from . import theme as thememod

ORGANIZATION = "ATLAS"
APPLICATION = "ATLAS-GUI"
THEME_FORMAT = 1         # the "atlas-theme" version a theme file is written in


def settings():
    """The settings store."""
    return QSettings(ORGANIZATION, APPLICATION)


def config_dir():
    """The ATLAS directory of the user's configuration."""
    base = QStandardPaths.writableLocation(
        QStandardPaths.StandardLocation.GenericConfigLocation)
    return os.path.join(base, ORGANIZATION)


def themes_dir():
    return os.path.join(config_dir(), "themes")


# ------------------------------------------------------------------ themes
def theme_to_data(spec):
    """What a theme file holds for *spec*."""
    return {"atlas-theme": THEME_FORMAT, "name": spec["name"],
            "base": spec.get("base", thememod.DEFAULT_THEME),
            "seeds": dict(spec["seeds"]),
            "overrides": dict(spec.get("overrides", {}))}


def read_theme_file(path):
    """The theme spec in *path*; ValueError when it is not a usable theme."""
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot be read as JSON ({exc})") from exc
    if not isinstance(data, dict) or "atlas-theme" not in data:
        raise ValueError("not an ATLAS theme (no \"atlas-theme\" key)")
    return thememod.spec_from_data(data)


def write_theme_file(spec, path):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(theme_to_data(spec), handle, indent=2)
        handle.write("\n")


def _file_names(names):
    """A distinct file name for each theme name.  Two names can reduce to
    the same stem ("My theme", "My-theme"), and macOS does not tell case
    apart, so the stems are made unique ignoring case."""
    files, used = {}, set()
    for name in names:
        stem = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-.") or "theme"
        candidate, suffix = stem, 2
        while candidate.lower() in used:
            candidate = f"{stem}-{suffix}"
            suffix += 1
        used.add(candidate.lower())
        files[name] = candidate + ".json"
    return files


def load_themes():
    """``(specs by name, problems)``: the user's themes, and one line per
    file that could not be used (it is left on disk untouched)."""
    specs, problems = {}, []
    directory = themes_dir()
    if not os.path.isdir(directory):
        return specs, problems
    for entry in sorted(os.listdir(directory)):
        if not entry.endswith(".json"):
            continue
        path = os.path.join(directory, entry)
        try:
            spec = read_theme_file(path)
        except ValueError as exc:
            problems.append(f"{entry}: {exc}")
            continue
        if thememod.is_builtin(spec["name"]) or spec["name"] in specs:
            problems.append(f"{entry}: the name {spec['name']!r} is taken")
            continue
        specs[spec["name"]] = spec
    return specs, problems


def save_themes(specs):
    """Make the themes directory hold exactly *specs*: write each one, and
    remove the theme files of names that are no longer there.  A file that
    is not an ATLAS theme is never touched."""
    directory = themes_dir()
    os.makedirs(directory, exist_ok=True)
    files = _file_names(specs)
    keep = set(files.values())
    for entry in os.listdir(directory):
        if not entry.endswith(".json") or entry in keep:
            continue
        path = os.path.join(directory, entry)
        try:
            read_theme_file(path)
        except ValueError:
            continue
        os.remove(path)
    for name, spec in specs.items():
        write_theme_file(spec, os.path.join(directory, files[name]))
