# Sleep Logger (Connect IQ watch-app — Venu 3 / Venu 3S)

A foreground overnight sleep logger that records the minimal signal set from
`sensor-lab/SLEEP_PARAMETERS.md`, classifies each 30 s epoch into
Wake / Light / Deep / REM, and shows a metrics + hypnogram summary on wake.

## Why a foreground session (not a background service)

Connect IQ background temporal events fire at a **~5-minute minimum interval** —
far too coarse for 30 s actigraphy epochs. So this is a foreground app the user
**starts at bedtime**; it stays alive overnight driven by a 30 s `Timer`, then
the user presses **START** again ("Stop / Wake") to end and view results.

## Runtime architecture

1. **Start screen** (`StartView` / `StartDelegate`): "Start sleep logging".
   START begins the session; once running it shows elapsed time + epoch count.
2. **Streaming** (`SensorData`): on start we `registerSensorDataListener` for
   accelerometer @25 Hz + `heartBeatIntervals` (RR). Gyro/mag/SpO2/GPS/temp are
   intentionally **not** streamed (battery). Stopped on session end.
3. **Epoch loop** (`SleepEngine`, 30 s `Timer`): each epoch computes a compact
   record and appends it to parallel arrays mirrored to `Application.Storage`:
   - `move`  — mean gravity-removed accel magnitude integrated over the epoch
   - `hr`    — `Sensor.getInfo().heartRate`
   - `rmssd` — RMSSD over a rolling, bounded RR buffer (cap 400 intervals)
   - `resp`  — `ActivityMonitor.getInfo().respirationRate`
   - epoch index (implicit array position) + session start timestamp
   Only summary numbers are stored — never raw 25 Hz streams. Hard cap of
   `MAX_EPOCHS = 1000` (~8.3 h) guards against unbounded growth.
4. **Stop / Wake** (`Staging`): runs the layered heuristic from the spec:
   - Wake by movement OR (elevated dHR + movement)
   - Immobility rule: onset = first ~10 min sustained-still block; final wake =
     last sleep epoch; the span between bounds the sleep period
   - within sleep: **Deep** = low HR (near nightly nadir) + high RMSSD + slow
     steady respiration + still; **REM** = low RMSSD + elevated/variable HR +
     irregular respiration + still, weighted to the later half of the night;
     else **Light**
   - single-epoch flips smoothed
5. **Results** (`ResultsView`): TST, sleep efficiency, onset latency (SOL),
   WASO, awakenings, time in bed, stage % (Light/Deep/REM), and a colour bar
   hypnogram (Wake/REM/Light/Deep lanes). UP/DOWN page, BACK returns.

## Honest limits

Per `SLEEP_PARAMETERS.md`: this is a **wellness/trend tool**, not PSG. Binary
sleep/wake is the strong case (~86-90% epoch accuracy) but wake specificity is
low (quiet wake reads as sleep -> TST overestimated, WASO underestimated). The
4-class hypnogram is a coarse surrogate (kappa ~0.4-0.6 at best). No apnea/AHI,
no EEG-defined stages, no microarousals.

## Files

- `manifest.xml`            — watch-app, venu3 + venu3s, minApiLevel 5.1.1,
                              permissions Sensor / SensorHistory / UserProfile
- `monkey.jungle`           — build config
- `resources/strings`       — app name
- `resources/drawables`     — launcher icon
- `source/SleepLoggerApp.mc`— entry point
- `source/SensorData.mc`    — verified reads (accel stream + RR buffer + HR/resp)
- `source/SleepEngine.mc`   — session lifecycle, 30 s epoch loop, Storage
- `source/Staging.mc`       — heuristic + metrics
- `source/StartView.mc` / `StartDelegate.mc`   — start/status screen
- `source/ResultsView.mc` / `ResultsDelegate.mc` — summary + hypnogram

## Build

```sh
export PATH="/Users/bhuvaneswarmarreddy/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/bin:/opt/homebrew/opt/openjdk/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
cd /Users/bhuvaneswarmarreddy/Desktop/Projects/garmin-watch-setup/creator/sleep-logger
monkeyc -d venu3  -f monkey.jungle -o /tmp/sleeplogger-venu3.prg  -y "/Users/bhuvaneswarmarreddy/garmin/developer_key" -l 3
monkeyc -d venu3s -f monkey.jungle -o /tmp/sleeplogger-venu3s.prg -y "/Users/bhuvaneswarmarreddy/garmin/developer_key" -l 3
```
