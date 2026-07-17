using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.ActivityMonitor;
using Toybox.UserProfile;
using Toybox.System;
using Toybox.Math;
using Toybox.Lang;

// Adapted from the compile-verified reads in sensor-lab/source/SensorData.mc.
// Trimmed to the minimal overnight signal set recommended in SLEEP_PARAMETERS.md:
// accel stream (movement), RR intervals (HRV), HR, respiration, baselines.
// Gyro / magnetometer / SpO2 / GPS / temperature are intentionally NOT streamed
// overnight (power/memory cost for little staging value).

// Hosts the raw high-frequency streaming callback. method(:onSensorData) must
// resolve against a class instance, so the callback lives here rather than in
// the module. Beyond caching the latest accel sample, this overnight version
// integrates accelerometer vector magnitude (gravity removed) across the whole
// epoch into _moveAccum, and buffers RR intervals so the engine can compute
// RMSSD over a rolling window.
class SensorDataStreamListener {
    public var lastAccel as Lang.Array<Lang.Numeric> or Null = null;   // [x, y, z] mg

    // Per-epoch integrated movement: sum of gravity-removed accel magnitudes
    // across every streamed sample. Reset by the engine at each epoch boundary.
    public var moveAccum as Lang.Float = 0.0;
    public var moveCount as Lang.Number = 0;

    // Rolling RR buffer (ms). Capacity bounded so memory never grows unbounded
    // across the night; ~5 min of beats at ~60 bpm fits comfortably in 400.
    public var rrBuf as Lang.Array<Lang.Number> = new [0];
    private const RR_CAP = 400;

    function initialize() {}

    // Reset the per-epoch movement accumulator (call at each epoch tick).
    function resetEpoch() as Void {
        moveAccum = 0.0;
        moveCount = 0;
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel != null) {
            var xArray = accel.x;
            var yArray = accel.y;
            var zArray = accel.z;
            if (xArray != null && yArray != null && zArray != null && xArray.size() > 0) {
                var n = xArray.size();
                // Cache latest sample for any live display.
                lastAccel = [xArray[n - 1], yArray[n - 1], zArray[n - 1]];
                // Integrate gravity-removed magnitude across the whole burst.
                // Gravity ~ 1000 mg; subtract the static 1 g vector length from
                // each sample's magnitude and accumulate the absolute residual.
                for (var i = 0; i < n; i++) {
                    var mx = xArray[i].toFloat();
                    var my = yArray[i].toFloat();
                    var mz = zArray[i].toFloat();
                    var mag = Math.sqrt(mx * mx + my * my + mz * mz);
                    var dyn = (mag - 1000.0).toFloat();  // remove ~1 g static component
                    if (dyn < 0) { dyn = -dyn; }
                    moveAccum = moveAccum + dyn;
                    moveCount += 1;
                }
            }
        }
        var hr = data.heartRateData;
        if (hr != null) {
            var intervals = hr.heartBeatIntervals;
            if (intervals != null && intervals.size() > 0) {
                for (var i = 0; i < intervals.size(); i++) {
                    var rr = intervals[i];
                    // Reject physiologically implausible RR (noise / dropped beats).
                    if (rr != null && rr >= 300 && rr <= 2000) {
                        rrBuf.add(rr);
                    }
                }
                // Bound the buffer.
                while (rrBuf.size() > RR_CAP) {
                    rrBuf = rrBuf.slice(rrBuf.size() - RR_CAP, rrBuf.size());
                }
            }
        }
    }
}

module SensorData {

    var _listener as SensorDataStreamListener or Null = null;

    // Lazily create + return the shared stream listener.
    function getListener() as SensorDataStreamListener {
        if (_listener == null) {
            _listener = new SensorDataStreamListener();
        }
        return _listener;
    }

    // Begin accelerometer + RR-interval streaming (the minimal overnight set).
    // Gyro / mag deliberately omitted to save battery overnight.
    function startStreaming() as Void {
        var l = getListener();
        Sensor.setEnabledSensors([Sensor.SENSOR_ONBOARD_HEARTRATE]);
        var options = {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => 25,
                :includeTimestamps => false
            },
            :heartBeatIntervals => {
                :enabled => true
            }
        };
        Sensor.registerSensorDataListener(l.method(:onSensorData), options);
    }

    // Stop streaming. Call on session end to save battery.
    function stopStreaming() as Void {
        Sensor.unregisterSensorDataListener();
    }

    // Instant HR snapshot (bpm) or null.
    function getHeartRate() as Lang.Number or Null {
        var info = Sensor.getInfo();
        return (info != null) ? info.heartRate : null;
    }

    // Respiration rate (breaths/min) or null. Garmin-derived, low cadence.
    function getRespiration() as Lang.Number or Null {
        var am = ActivityMonitor.getInfo();
        return (am != null) ? am.respirationRate : null;
    }

    // Personal resting HR baseline (bpm) for relative dHR thresholds.
    function getRestingHr() as Lang.Number {
        var prof = UserProfile.getProfile();
        if (prof != null && prof.restingHeartRate != null) {
            return prof.restingHeartRate as Lang.Number;
        }
        return 60; // safe default if the profile is unset in the sim
    }
}
