using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.ActivityMonitor;
using Toybox.Activity;
using Toybox.UserProfile;
using Toybox.Position;
using Toybox.Weather;
using Toybox.System;
using Toybox.Math;
using Toybox.Time;
using Toybox.Lang;

// Hosts the raw high-frequency streaming callback. method(:onSensorData)
// must resolve against a class instance, so the callback lives here rather
// than in the module (compiler error otherwise: "Cannot find symbol :method
// on type 'self'").
//
// Beyond logging, it caches the most recent accelerometer / gyroscope /
// magnetometer / RR sample so the Motion page can render live x/y/z values.
class SensorDataStreamListener {
    public var lastAccel as Lang.Array<Lang.Numeric> or Null = null;   // [x, y, z] mg
    public var lastGyro as Lang.Array<Lang.Numeric> or Null = null;    // [x, y, z]
    public var lastMag as Lang.Array<Lang.Numeric> or Null = null;     // [x, y, z]
    public var lastRR as Lang.Number or Null = null;     // ms

    function initialize() {}

    function onSensorData(data as Sensor.SensorData) as Void {
        var accel = data.accelerometerData;
        if (accel != null) {
            var xArray = accel.x;
            var yArray = accel.y;
            var zArray = accel.z;
            if (xArray != null && yArray != null && zArray != null && xArray.size() > 0) {
                var n = xArray.size() - 1;
                lastAccel = [xArray[n], yArray[n], zArray[n]];
            }
        }
        var mag = data.magnetometerData;
        if (mag != null) {
            var mx = mag.x;
            var my = mag.y;
            var mz = mag.z;
            if (mx != null && my != null && mz != null && mx.size() > 0) {
                var n = mx.size() - 1;
                lastMag = [mx[n], my[n], mz[n]];
            }
        }
        var gyro = data.gyroscopeData;
        if (gyro != null) {
            var gx = gyro.x;
            var gy = gyro.y;
            var gz = gyro.z;
            if (gx != null && gy != null && gz != null && gx.size() > 0) {
                var n = gx.size() - 1;
                lastGyro = [gx[n], gy[n], gz[n]];
            }
        }
        var hr = data.heartRateData;
        if (hr != null) {
            var intervals = hr.heartBeatIntervals;
            if (intervals != null && intervals.size() > 0) {
                lastRR = intervals[intervals.size() - 1];
            }
        }
    }
}

module SensorData {

    var _listener as SensorDataStreamListener or Null = null;

    // Lazily create + return the shared stream listener so the Motion page
    // can read the latest cached high-frequency samples.
    function getListener() as SensorDataStreamListener {
        if (_listener == null) {
            _listener = new SensorDataStreamListener();
        }
        return _listener;
    }

    // Begin raw accelerometer/magnetometer/gyroscope/RR-interval streaming.
    // Call from a View.onShow().
    function startStreaming() as Void {
        var l = getListener();
        var options = {
            :period => 1,
            :accelerometer => {
                :enabled => true,
                :sampleRate => 25,
                :includePower => true,
                :includePitch => true,
                :includeRoll => true,
                :includeTimestamps => true
            },
            :magnetometer => {
                :enabled => true,
                :sampleRate => 25,
                :includeTimestamps => true
            },
            :gyroscope => {
                :enabled => true,
                :sampleRate => 25,
                :includeTimestamps => true
            },
            :heartBeatIntervals => {
                :enabled => true
            }
        };
        Sensor.registerSensorDataListener(l.method(:onSensorData), options);
    }

    // Stop streaming. Call from a View.onHide().
    function stopStreaming() as Void {
        Sensor.unregisterSensorDataListener();
    }

    function s(v as Lang.Object or Null) as Lang.String {
        return (v != null) ? v.toString() : "--";
    }

    // ---- Per-page reads. Each returns an Array of [label, value] pairs. ----

    // Make sure on-board sensors we poll synchronously are enabled.
    function enableSensors() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_ONBOARD_HEARTRATE, Sensor.SENSOR_TEMPERATURE]);
    }

    // Page 1: Vitals
    function readVitals() as Lang.Array<Lang.Array<Lang.String>> {
        var out = [];
        enableSensors();
        var info = Sensor.getInfo();
        out.add(["Heart Rate", s(info.heartRate) + " bpm"]);
        out.add(["SpO2", s(info.oxygenSaturation) + " %"]);

        var l = getListener();
        out.add(["HRV (RR)", (l.lastRR != null) ? s(l.lastRR) + " ms" : "--"]);

        var am = ActivityMonitor.getInfo();
        out.add(["Respiration", s(am.respirationRate)]);

        var bbIter = SensorHistory.getBodyBatteryHistory({});
        if (bbIter != null) {
            var bs = bbIter.next();
            out.add(["Body Battery", (bs != null) ? s(bs.data) : "--"]);
        } else {
            out.add(["Body Battery", "--"]);
        }
        var stIter = SensorHistory.getStressHistory({});
        if (stIter != null) {
            var ss = stIter.next();
            out.add(["Stress", (ss != null) ? s(ss.data) : "--"]);
        } else {
            out.add(["Stress", "--"]);
        }
        var hrIter = SensorHistory.getHeartRateHistory({});
        if (hrIter != null) {
            out.add(["HR Min/Max", s(hrIter.getMin()) + "/" + s(hrIter.getMax())]);
        } else {
            out.add(["HR Min/Max", "--"]);
        }
        out.add(["Resting HR", s(UserProfile.getProfile().restingHeartRate) + " bpm"]);
        return out;
    }

    // Page 2: Motion (raw streaming + activity-monitor movement)
    function readMotion() as Lang.Array<Lang.Array<Lang.String>> {
        var out = [];
        var l = getListener();

        var a = l.lastAccel;
        if (a != null) {
            out.add(["Accel X", s(a[0]) + " mg"]);
            out.add(["Accel Y", s(a[1]) + " mg"]);
            out.add(["Accel Z", s(a[2]) + " mg"]);
        } else {
            // Fall back to instantaneous Sensor.getInfo accel if the stream
            // has not delivered a sample yet.
            var info = Sensor.getInfo();
            var ac = info.accel;
            if (ac != null) {
                out.add(["Accel X", s(ac[0]) + " mg"]);
                out.add(["Accel Y", s(ac[1]) + " mg"]);
                out.add(["Accel Z", s(ac[2]) + " mg"]);
            } else {
                out.add(["Accel X", "--"]);
                out.add(["Accel Y", "--"]);
                out.add(["Accel Z", "--"]);
            }
        }

        var g = l.lastGyro;
        if (g != null) {
            out.add(["Gyro X/Y/Z", s(g[0]) + "/" + s(g[1]) + "/" + s(g[2])]);
        } else {
            out.add(["Gyro X/Y/Z", "--"]);
        }
        var m = l.lastMag;
        if (m != null) {
            out.add(["Mag X/Y/Z", s(m[0]) + "/" + s(m[1]) + "/" + s(m[2])]);
        } else {
            out.add(["Mag X/Y/Z", "--"]);
        }

        var am = ActivityMonitor.getInfo();
        out.add(["Steps", s(am.steps) + "/" + s(am.stepGoal)]);
        out.add(["Floors", s(am.floorsClimbed) + "/" + s(am.floorsClimbedGoal)]);
        out.add(["Distance", s(am.distance) + " cm"]);

        var ai = Activity.getActivityInfo();
        out.add(["Cadence", (ai != null) ? s(ai.currentCadence) : "--"]);
        return out;
    }

    // Page 3: Environment
    function readEnvironment() as Lang.Array<Lang.Array<Lang.String>> {
        var out = [];
        enableSensors();
        var info = Sensor.getInfo();
        out.add(["Pressure", s(info.pressure) + " Pa"]);
        out.add(["Altitude", s(info.altitude) + " m"]);
        out.add(["Temperature", s(info.temperature) + " C"]);

        var headingRad = info.heading;
        if (headingRad != null) {
            var hd = (headingRad * 180.0 / Math.PI);
            out.add(["Heading", s(hd.toNumber()) + " deg"]);
        } else {
            out.add(["Heading", "--"]);
        }

        var wc = Weather.getCurrentConditions();
        if (wc != null) {
            out.add(["Wx Temp", s(wc.temperature) + " C"]);
            out.add(["Wx Humidity", s(wc.relativeHumidity) + " %"]);
            out.add(["Wx Wind", s(wc.windSpeed)]);
        } else {
            out.add(["Wx Temp", "--"]);
            out.add(["Wx Humidity", "--"]);
            out.add(["Wx Wind", "--"]);
        }

        var pos = Position.getInfo();
        var posLoc = (pos != null) ? pos.position : null;
        if (posLoc != null) {
            var deg = posLoc.toDegrees();
            out.add(["Latitude", s(deg[0])]);
            out.add(["Longitude", s(deg[1])]);
        } else {
            out.add(["Latitude", "--"]);
            out.add(["Longitude", "--"]);
        }
        out.add(["GPS Speed", (pos != null) ? s(pos.speed) : "--"]);
        out.add(["GPS Accuracy", (pos != null) ? s(pos.accuracy) : "--"]);
        return out;
    }

    // Page 4: System & Profile
    function readSystem() as Lang.Array<Lang.Array<Lang.String>> {
        var out = [];
        var stats = System.getSystemStats();
        out.add(["Battery", s(stats.battery) + " %"]);
        out.add(["Battery Days", s(stats.batteryInDays)]);
        out.add(["Charging", s(stats.charging)]);
        out.add(["Free Mem", s(stats.freeMemory)]);
        out.add(["Used Mem", s(stats.usedMemory)]);

        var prof = UserProfile.getProfile();
        out.add(["Birth Year", s(prof.birthYear)]);
        out.add(["Weight", s(prof.weight) + " g"]);
        out.add(["Height", s(prof.height) + " cm"]);
        out.add(["VO2 Run", s(prof.vo2maxRunning)]);
        out.add(["Avg RHR", s(prof.averageRestingHeartRate) + " bpm"]);

        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        out.add(["HR Zones", (zones != null && zones.size() >= 6) ? s(zones[0]) + "-" + s(zones[5]) : "--"]);
        return out;
    }
}
