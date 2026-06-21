# Bhuvi Vintage Analog — Venu 3 / Venu 3S watch face

**Version 1.2.0** (set the Connect IQ Store *App Version* field to `1.2.0` on upload).

A vintage-styled Connect IQ watch face for the **Garmin Venu 3 / Venu 3S**, with a
Rolex-inspired layout and fully configurable settings.

## The face (analog)
- **Title** at 12 o'clock (gilt-gold) — your custom text
- **Pointed lance hands** (outline or filled), ivory/gold/white/rose-gold
- **Gold center hub** + **gold ticking second hand**
- **Date** number window at **3 o'clock** (Rolex Datejust / Cyclops style)
- **Day-of-week** window at **9 o'clock** (Day-Date style)
- Black dial (AMOLED-friendly), antialiased
- **Always-on (low-power) mode:** same hands at the same size, dimmed to grey,
  complications/title hidden — keeps lit pixels low to protect the AMOLED
- A **Digital** layout is also included (time, date, battery, steps)

## Settings (Garmin Connect → watch face → Settings, or the simulator's Settings menu)
| Setting | Type | Options (default) |
|---|---|---|
| Title Text | text | any text (`B H U V I`) |
| Title Size | number | 8–40 (`18`) |
| Face Style | list | Digital / **Analog** |
| Hand Style | list | **Outline** / Filled |
| Hand Color | list | **Ivory** / Gold / White / Rose Gold |
| Accent Color | list | White / Blue / Green / Orange / Red (digital) |
| Show Title | toggle | on |
| Show Day | toggle | on |
| Show Date | toggle | on |
| Show Seconds | toggle | on (awake only) |
| Show Steps | toggle | off (digital) |
| Show Battery | toggle | on (digital) |

## Build / run
```bash
# from this folder, with the SDK's monkeyc on PATH and Java available
monkeyc -d venu3 -f monkey.jungle -o out.prg -y ~/garmin/developer_key -l 3   # device/sim build
monkeyc -e      -f monkey.jungle -o Bhuvi-Venu3-WatchFace.iq -y ~/garmin/developer_key -l 3   # store package
```
- `-l 3` is the strict type-check level (release quality — the project builds clean at this level).
- In VS Code with the Monkey C extension: press **F5** to run in the simulator.

## Files
- `source/VenuWatchFaceApp.mc` — entry point (redraws on settings change).
- `source/VenuWatchFaceView.mc` — the whole face: digital + analog drawing, hands, complications, helpers.
- `resources/settings/` — `properties.xml` (defaults) + `settings.xml` (the settings UI).
- `resources/strings/strings.xml` — app name + all setting labels.
- `resources/drawables/` — launcher icon.

## Notes
- Hands/complications are gold-accented; colours are 24-bit (full-colour AMOLED).
- The title/day use the device's scalable **RobotoRegular** vector font, so the
  title size can be any pixel value.
- Saved settings persist on device — changing a *default* only affects a fresh
  install; existing installs keep their chosen values.
