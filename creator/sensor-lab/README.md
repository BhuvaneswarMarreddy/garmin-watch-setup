# Sensor Lab

A Connect IQ **watch app** for the Garmin Venu 3 (454x454) and Venu 3S (390x390)
that surfaces the maximum set of live device sensor readings, paginated across
four swipeable screens. Black background, round-screen-aware layout, values
refresh once per second, and every reading is null-safe (shows `--` when
unavailable).

- Type: `watch-app`
- minApiLevel: `5.1.1`
- Permissions: `Sensor`, `SensorHistory`, `UserProfile`, `Positioning`
- Targets: `venu3`, `venu3s`

## Navigation

Swipe up / left (or the next-page behavior) advances; swipe down / right (or the
previous-page behavior) goes back. Pages wrap around. The header shows the page
title and a `page N/4` indicator.

The **raw accelerometer / gyroscope / magnetometer / RR-interval stream**
(`Sensor.registerSensorDataListener`, 25 Hz) is started only when the Motion
page becomes visible and stopped when you leave it (or when the app is hidden),
to save battery.

## Pages and the exact sensors on each

### Page 1 - Vitals
- Heart Rate (`Sensor.getInfo().heartRate`)
- SpO2 (`Sensor.getInfo().oxygenSaturation`)
- HRV / RR interval (streamed `heartRateData.heartBeatIntervals`)
- Respiration (`ActivityMonitor.getInfo().respirationRate`)
- Body Battery (`SensorHistory.getBodyBatteryHistory`)
- Stress (`SensorHistory.getStressHistory`)
- HR Min/Max (`SensorHistory.getHeartRateHistory` getMin/getMax)
- Resting HR (`UserProfile.getProfile().restingHeartRate`)

### Page 2 - Motion
- Accel X / Y / Z - live raw stream (`accelerometerData`, falls back to
  `Sensor.getInfo().accel` until the first stream sample arrives)
- Gyro X/Y/Z - live raw stream (`gyroscopeData`)
- Mag X/Y/Z - live raw stream (`magnetometerData`)
- Steps / step goal (`ActivityMonitor.getInfo().steps`, `.stepGoal`)
- Floors / floor goal (`.floorsClimbed`, `.floorsClimbedGoal`)
- Distance (`.distance`, cm)
- Cadence (`Activity.getActivityInfo().currentCadence`)

### Page 3 - Environment
- Pressure (`Sensor.getInfo().pressure`, Pa)
- Altitude (`Sensor.getInfo().altitude`, m)
- Temperature (`Sensor.getInfo().temperature`, C)
- Heading (`Sensor.getInfo().heading`, converted to degrees)
- Weather temp (`Weather.getCurrentConditions().temperature`)
- Weather humidity (`.relativeHumidity`)
- Weather wind (`.windSpeed`)
- GPS Latitude / Longitude (`Position.getInfo().position.toDegrees()`)
- GPS Speed (`Position.getInfo().speed`)
- GPS Accuracy (`Position.getInfo().accuracy`)

### Page 4 - System & Profile
- Battery (`System.getSystemStats().battery`)
- Battery Days (`.batteryInDays`)
- Charging (`.charging`)
- Free Memory (`.freeMemory`)
- Used Memory (`.usedMemory`)
- Birth Year (`UserProfile.getProfile().birthYear`)
- Weight (`.weight`, g)
- Height (`.height`, cm)
- VO2max Running (`.vo2maxRunning`)
- Average Resting HR (`.averageRestingHeartRate`)
- HR Zones (`UserProfile.getHeartRateZones(HR_ZONE_SPORT_GENERIC)`, low-high)

## Building

```sh
export PATH="/Users/bhuvaneswarmarreddy/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2/bin:/opt/homebrew/opt/openjdk/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"

cd garmin-watch-setup/creator/sensor-lab
monkeyc -d venu3  -f monkey.jungle -o /tmp/sensorlab-venu3.prg  -y ~/garmin/developer_key -l 3
monkeyc -d venu3s -f monkey.jungle -o /tmp/sensorlab-venu3s.prg -y ~/garmin/developer_key -l 3
```

Both devices build clean at strict type-check level (`-l 3`).

## Source layout

- `source/SensorLabApp.mc` - app entry point; returns the view + delegate.
- `source/SensorLabView.mc` - paged view, 1s refresh timer, stream lifecycle.
- `source/SensorLabDelegate.mc` - swipe / next-page / previous-page navigation.
- `source/SensorData.mc` - all sensor reads + the raw streaming listener.
