# Venu 3 Heart-Rate Data Field — starter project

A minimal Connect IQ **data field** for the Garmin Venu 3 / Venu 3S. It shows
your **current heart rate** inside any activity (run, bike, walk, …).

A *data field* is different from a *watch face*: it appears in the data boxes
during a recorded activity, not on the main clock screen.

## Run it
1. Open this folder in VS Code (Monkey C extension installed).
2. Press <kbd>F5</kbd> → choose **Venu 3**.
3. In the simulator, start a simulated activity to see the field
   (the simulator can feed fake sensor data: **Simulation → ...** menu).

(Full toolchain install steps are in the top-level `README.md`.)

## Files
- `manifest.xml` — type=`datafield`, targets `venu3` + `venu3s`.
- `source/HeartRateFieldApp.mc` — entry point.
- `source/HeartRateFieldView.mc` — a `SimpleDataField`; edit `compute()` to show
  a different metric (pace, cadence, power, a custom calculation, …).

## Ideas to extend
- Return `info.currentSpeed`, `info.currentCadence`, or `info.energyExpenditure`.
- Switch from `SimpleDataField` to `DataField` to draw a fully custom layout
  (graphs, gauges, colors) with your own `onUpdate(dc)`.
