# The token lives outside portable_config so it can never be committed, synced
# or copied along with the config. CryptProtectData ties the blob to the Windows
# account that wrote it, so the file is inert anywhere else. It is not
# protection from code already running as you.

import ctypes
import json
import os
from ctypes import wintypes

_ENTROPY = b"mpv-anilist-updater"
_DIR = os.path.join(os.environ["LOCALAPPDATA"], "mpv-anilist")
_PATH = os.path.join(_DIR, "token.dat")
_LEGACY = os.path.join(os.path.dirname(__file__), "anilistToken.txt")


class _Blob(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]


def _crypt(fn, data):
    # The source buffers must outlive the call, so they stay named locals.
    source = ctypes.create_string_buffer(data, len(data))
    entropy = ctypes.create_string_buffer(_ENTROPY, len(_ENTROPY))
    blob_in = _Blob(len(data), ctypes.cast(source, ctypes.POINTER(ctypes.c_char)))
    blob_entropy = _Blob(len(_ENTROPY), ctypes.cast(entropy, ctypes.POINTER(ctypes.c_char)))
    blob_out = _Blob()

    if not fn(ctypes.byref(blob_in), None, ctypes.byref(blob_entropy),
              None, None, 0, ctypes.byref(blob_out)):
        raise OSError(ctypes.GetLastError(), f"{fn.__name__} failed")

    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(blob_out.pbData)


def _adopt_legacy():
    """One-time import of the plaintext anilistToken.txt this replaced."""
    try:
        with open(_LEGACY) as file:
            content = file.read().strip()
    except OSError:
        return None, None

    if not content:
        return None, None

    user_id, _, token = content.partition(":")
    if not token:
        user_id, token = None, user_id

    save(token, int(user_id) if user_id else None)
    return token, int(user_id) if user_id else None


def load():
    """The stored token and cached user id, both None until setup has run."""
    try:
        with open(_PATH, "rb") as file:
            blob = file.read()
    except OSError:
        return _adopt_legacy()

    stored = json.loads(_crypt(ctypes.windll.crypt32.CryptUnprotectData, blob))
    return stored.get("token"), stored.get("user_id")


def save(token, user_id=None):
    os.makedirs(_DIR, exist_ok=True)
    payload = json.dumps({"token": token, "user_id": user_id}).encode()
    blob = _crypt(ctypes.windll.crypt32.CryptProtectData, payload)

    with open(_PATH, "wb") as file:
        file.write(blob)
