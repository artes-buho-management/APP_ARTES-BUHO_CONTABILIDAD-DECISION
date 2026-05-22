# Contabilidad AppScript Workspace

This folder is ready to develop the app bound to spreadsheet:
- https://docs.google.com/spreadsheets/d/REPLACE_WITH_SHEET_ID/edit

## Files
- `.clasp.json`: points to bound script id.
- `appsscript.json`: Apps Script manifest.
- `Code.js`: base app logic.
- `scripts/push_api.ps1`: push local files to Apps Script.
- `scripts/pull_api.ps1`: pull latest Apps Script files to local.

## Sync commands
From this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\push_api.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pull_api.ps1
```

Token profile used by default: `default` (booking@artesbuhomanagement.com).
If `default` fails during pull, `scripts/pull_api.ps1` now tries the remaining profiles from `.clasprc.json` automatically.

