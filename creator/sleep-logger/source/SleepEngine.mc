using Toybox.Timer;
using Toybox.Application;
using Toybox.Application.Storage;
using Toybox.System;
using Toybox.Math;
using Toybox.Time;
using Toybox.Lang;
using Toybox.WatchUi;

// Owns the overnight logging session: a 30 s foreground Timer that, each epoch,
// reads the cached signals, computes a compact feature record, and appends it to
// parallel arrays persisted in Application.Storage.
//
// Memory discipline: we store ONLY per-epoch summary numbers (5 small arrays),
// never raw 25 Hz streams. A full night ~ 960 epochs * 5 numbers = tiny.
class SleepEngine {

    public const EPOCH_SEC = 30;
    public const MAX_EPOCHS = 1000;   // ~8.3 h hard cap; guards unbounded growth

    // Storage keys.
    private const K_MOVE = "move";    // integrated movement index (mean dyn accel)
    private const K_HR   = "hr";      // mean HR (bpm)
    private const K_RMS  = "rmssd";   // RMSSD over rolling RR window (ms)
    private const K_RESP = "resp";    // respiration rate (brk/min)
    private const K_TS    = "startTs"; // session start epoch seconds
    private const K_RHR   = "rhr";     // resting HR baseline

    private var _timer as Timer.Timer or Null = null;
    public var running as Lang.Boolean = false;
    public var startMoment as Lang.Number = 0;   // System time seconds at start
    public var epochCount as Lang.Number = 0;

    // In-memory parallel feature arrays (mirrored to Storage each epoch).
    // Declared as the Storage-compatible element type so setValue() type-checks.
    public var moveArr as Lang.Array<Lang.Float> = new [0];
    public var hrArr as Lang.Array<Lang.Number> = new [0];
    public var rmssdArr as Lang.Array<Lang.Float> = new [0];
    public var respArr as Lang.Array<Lang.Number> = new [0];

    public var restingHr as Lang.Number = 60;
    public var lastHr as Lang.Number = 0;

    function initialize() {}

    function isRunning() as Lang.Boolean { return running; }

    // Elapsed seconds since start (0 if not running).
    function elapsedSec() as Lang.Number {
        if (!running) { return 0; }
        return System.getTimer() != null ? (System.getTimer() / 1000) - startMoment : 0;
    }

    function start() as Void {
        if (running) { return; }
        running = true;
        epochCount = 0;
        moveArr = new [0];
        hrArr = new [0];
        rmssdArr = new [0];
        respArr = new [0];
        startMoment = System.getTimer() / 1000;
        restingHr = SensorData.getRestingHr();

        // Clear any previous night's record.
        Storage.clearValues();
        Storage.setValue(K_TS, Time.now().value());
        Storage.setValue(K_RHR, restingHr);

        SensorData.startStreaming();
        SensorData.getListener().resetEpoch();

        _timer = new Timer.Timer();
        _timer.start(method(:onEpoch), EPOCH_SEC * 1000, true);
    }

    // Stop the session and the sensors. Returns nothing; the caller then runs
    // staging on the collected arrays.
    function stop() as Void {
        if (!running) { return; }
        running = false;
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        SensorData.stopStreaming();
    }

    // Timer callback: one 30 s epoch.
    function onEpoch() as Void {
        if (!running) { return; }
        if (epochCount >= MAX_EPOCHS) {
            // Safety cap reached; stop streaming but leave data intact.
            stop();
            return;
        }

        var l = SensorData.getListener();

        // 1. Movement index: mean gravity-removed accel magnitude over the epoch.
        var move = 0.0;
        if (l.moveCount > 0) {
            move = l.moveAccum / l.moveCount;
        }
        l.resetEpoch();

        // 2. Mean HR (snapshot is adequate at 1x/epoch).
        var hr = SensorData.getHeartRate();
        if (hr == null) { hr = lastHr; }
        if (hr == null) { hr = 0; }
        lastHr = hr;

        // 3. RMSSD over the rolling RR buffer.
        var rmssd = computeRmssd(l.rrBuf);

        // 4. Respiration rate.
        var resp = SensorData.getRespiration();
        if (resp == null) { resp = 0; }

        // Append (capped).
        moveArr.add(move);
        hrArr.add(hr);
        rmssdArr.add(rmssd);
        respArr.add(resp);
        epochCount += 1;

        // Persist compact arrays. (Numbers only; no raw streams.)
        // Cast to the Storage value type; Float/Number arrays are valid values.
        Storage.setValue(K_MOVE, moveArr as Application.Storage.ValueType);
        Storage.setValue(K_HR, hrArr as Application.Storage.ValueType);
        Storage.setValue(K_RMS, rmssdArr as Application.Storage.ValueType);
        Storage.setValue(K_RESP, respArr as Application.Storage.ValueType);

        WatchUi.requestUpdate();
    }

    // RMSSD = sqrt(mean of squared successive RR differences) over the buffer.
    function computeRmssd(rr as Lang.Array<Lang.Number>) as Lang.Float {
        var n = rr.size();
        if (n < 2) { return 0.0; }
        var sumSq = 0.0;
        var cnt = 0;
        for (var i = 1; i < n; i++) {
            var d = (rr[i] - rr[i - 1]).toFloat();
            sumSq += d * d;
            cnt += 1;
        }
        if (cnt == 0) { return 0.0; }
        return Math.sqrt(sumSq / cnt).toFloat();
    }
}
