# Venu 3 Custom Watch Face — starter project

A Connect IQ watch face for the **Garmin Venu 3 / Venu 3S** with:
- **Digital and analog** styles (switchable in settings)
- **User settings** (configured in the Garmin Connect phone app): face style,
  accent color, and show/hide toggles for seconds, steps, and battery
- **Always-on (low-power) mode** that strips the face down to protect the AMOLED
  screen and save battery

## Run it
1. Open this folder in VS Code (with the Monkey C extension installed).
2. Press <kbd>F5</kbd> → choose **Venu 3** → the simulator opens.

(Full toolchain install steps are in the parent folder's `README.md`.)

## Trying the features in the simulator
- **Always-on / low-power look:** in the simulator menu, toggle the display
  power state (look for *Always On Display* / *Low Power Mode* under the
  simulator's display or watch menu). The face redraws with fewer lit pixels.
- **Settings (themes/toggles):** in the simulator, open the app settings editor
  (under the simulator's **Settings** menu) to change Face Style, Accent Color,
  etc. On a real watch these appear in **Garmin Connect → your watch face →
  Settings**.

## Files
- `manifest.xml` — app id, type=`watchface`, targets `venu3` + `venu3s`.
- `monkey.jungle` — build config.
- `source/VenuWatchFaceApp.mc` — entry point; redraws on settings change.
- `source/VenuWatchFaceView.mc` — **the design**: `drawDigital()`, `drawAnalog()`,
  and the low-power branch all live here.
- `resources/settings/properties.xml` — default values for each setting.
- `resources/settings/settings.xml` — the settings UI shown in Garmin Connect.
- `resources/strings/strings.xml` — app name + setting labels.
- `resources/drawables/` — launcher icon (swap in your own PNG art).

## Notes
- The `id` in `manifest.xml` was pre-generated for this project. Start a
  brand-new project from scratch later and let the extension generate a fresh id.
- You'll be prompted for a **developer key** on first build — see parent README, Step 5.
- **Live seconds:** they tick only while the watch is awake (the system calls
  `onUpdate` ~1×/sec then). For a *ticking second hand in always-on mode* you'd
  add `onPartialUpdate(dc)` with a clip region — see Garmin's "Analog" sample and
  the Core Topics → "Watch Faces" docs.
