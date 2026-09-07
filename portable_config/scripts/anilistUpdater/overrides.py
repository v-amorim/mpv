# Series the filename guesser gets wrong, pinned to the entry you picked.
# Keyed on the name guessit parses out rather than the folder, so the same show
# stays pinned when episodes live in per-season directories.

import json
import os

_PATH = os.path.join(os.environ["LOCALAPPDATA"], "mpv-anilist", "overrides.json")


def _key(name):
    return " ".join(name.lower().split())


def _read():
    try:
        with open(_PATH, encoding="utf-8") as file:
            return json.load(file)
    except (OSError, ValueError):
        return {}


def get(name):
    return _read().get(_key(name))


def put(name, anime_id, title):
    stored = _read()
    stored[_key(name)] = {"id": anime_id, "title": title}

    os.makedirs(os.path.dirname(_PATH), exist_ok=True)
    with open(_PATH, "w", encoding="utf-8") as file:
        json.dump(stored, file, indent=2, ensure_ascii=False)
