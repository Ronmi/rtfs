# Translations

rtfs is written in Traditional Chinese (`zh_TW`); every other language is a translation table here.

- `<lang>.json` maps source text → translation, e.g. `"電池 %1%": "Battery %1%"`.
  An empty or missing translation shows the source text.
- `%1`, `%2`, … are filled in by the program; keep them (the order may change).
  Keep `\n`, HTML tags such as `<b>`, and `%%` (a literal `%` in command-line help) as they are.
- Date formats such as `yyyy年M月d日 dddd` are Qt date format strings; translate them to the
  format your language uses (e.g. `dddd, MMMM d, yyyy`).

The language is picked like gettext does: `LANGUAGE` (a colon-separated list), then the first of
`LC_ALL` / `LC_MESSAGES` / `LANG`; each is tried as `ll_CC.json`, then `ll.json`.
The shell (`shell/I18n.qml`) and the scripts (`scripts/rtfs_i18n.py`) share these files.

To add or update a language:

```sh
scripts/i18n-update en          # create/update shell/i18n/en.json with every string, new ones empty
scripts/i18n-update en --check  # list untranslated / obsolete strings
```

Then fill in the empty values and restart QuickShell (`qs kill; qs -n`).
