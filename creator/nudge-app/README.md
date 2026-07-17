# Nudge — Venu 3 / Venu 3S app

A tiny Connect IQ **watch app** for learning on-device **alerts ("notifications")**.

It counts down (default 60s) and, when it reaches zero — or when you tap / press
Start — it fires an alert through every channel the watch has:

- **Vibrate** (`Attention.vibrate`)
- **Tone / beep** (`Attention.playTone`)
- **Backlight flash** (`Attention.backlight`)
- **Toast pop-up** (`WatchUi.showToast`)

> Connect IQ apps can't post *phone* notifications — these are the on-device
> alert tools, which is what "notifications" means on the watch.

## Controls
- **Tap screen / Start button** → fire a test nudge now
- **Menu** → pause / resume the countdown
- **Back** → exit

## Run it
```bash
# with the SDK's monkeyc on PATH + Java available
monkeyc -d venu3 -f monkey.jungle -o out.prg -y ~/garmin/developer_key -l 3
# then load into the simulator with: monkeydo out.prg venu3
```
Or in VS Code (Monkey C extension): open this folder, press **F5**, pick **Venu 3**.

## Files
- `source/NudgeApp.mc` — entry point (returns a View **+ delegate**).
- `source/NudgeView.mc` — the screen + the `nudge()` alert + a 1-second `Timer`.
- `source/NudgeDelegate.mc` — button/tap handling (`BehaviorDelegate`).
- `resources/` — app name + launcher icon.

## What this teaches
- `type="watch-app"` (a launchable app vs. a watch face)
- `Toybox.Attention` for vibrate / tone / backlight
- `WatchUi.showToast` for a toast message (guarded with `has`)
- `Toybox.Timer` for a repeating timer
- `WatchUi.BehaviorDelegate` for input (`onSelect` / `onTap` / `onMenu` / `onBack`)
