"""Interface text translation for the rtfs scripts, same rules and files as shell/I18n.qml.

Source strings are Traditional Chinese; shell/i18n/<lang>.json maps source -> translation
(empty or missing = show the source). The language comes from LANGUAGE (colon list), then the
first of LC_ALL / LC_MESSAGES / LANG; each is tried as ll_CC.json, then ll.json, stopping at the
source language (zh_TW / zh).

Usage: `from rtfs_i18n import tr` then `tr("電池 %1%", 42)`. Only literal first arguments are
picked up by scripts/i18n-update.
"""

import json
import os

SOURCE_LANGUAGE = "zh_TW"
# scripts/ and shell/ are siblings both in the repo and in /usr/share/rtfs.
I18N_DIR = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "shell", "i18n")


def candidates():
    names = [n for n in os.environ.get("LANGUAGE", "").split(":") if n]
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        if os.environ.get(var):
            names.append(os.environ[var])
            break
    out = []
    for name in names:
        lang = name.split(".")[0].split("@")[0]
        if not lang or lang in ("C", "POSIX"):
            continue
        for c in (lang, lang.split("_")[0]):
            if c not in out:
                out.append(c)
    return out


def _load():
    for lang in candidates():
        if lang in (SOURCE_LANGUAGE, SOURCE_LANGUAGE.split("_")[0]):
            break
        try:
            with open(os.path.join(I18N_DIR, lang + ".json"), encoding="utf-8") as f:
                return lang, json.load(f)
        except (OSError, ValueError):
            continue
    return SOURCE_LANGUAGE, {}


LANGUAGE, _CATALOG = _load()


def tr(text, *args):
    out = _CATALOG.get(text) or text
    for i in range(len(args), 0, -1):
        out = out.replace("%" + str(i), str(args[i - 1]))
    return out
