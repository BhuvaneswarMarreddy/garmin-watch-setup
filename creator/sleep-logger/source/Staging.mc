using Toybox.Math;
using Toybox.Lang;

// Implements the layered staging heuristic from SLEEP_PARAMETERS.md and derives
// the night's sleep metrics from the per-epoch feature arrays.
//
// Stage codes (used in the hypnogram array):
//   0 = WAKE, 1 = LIGHT (N1+N2), 2 = DEEP (N3), 3 = REM
module Staging {

    const WAKE  = 0;
    const LIGHT = 1;
    const DEEP  = 2;
    const REM   = 3;

    // Movement threshold (mean gravity-removed accel, mg) above which an epoch is
    // treated as "moving". PPG accel noise at rest is small; rolling over / wake
    // motion is far larger. Tunable.
    const MOVE_WAKE = 60.0;
    const MOVE_QUIET = 25.0;   // "essentially still" gate for DEEP

    // Result container.
    class StageResult {
        public var stages as Lang.Array<Lang.Number>;   // per-epoch stage code
        public var totalEpochs as Lang.Number = 0;
        public var sleepEpochs as Lang.Number = 0;
        public var lightEpochs as Lang.Number = 0;
        public var deepEpochs as Lang.Number = 0;
        public var remEpochs as Lang.Number = 0;
        public var wakeEpochs as Lang.Number = 0;
        public var onsetIdx as Lang.Number = -1;        // first sustained sleep epoch
        public var finalWakeIdx as Lang.Number = -1;    // last sleep epoch + 1 boundary
        public var wasoEpochs as Lang.Number = 0;       // wake epochs inside sleep period
        public var awakenings as Lang.Number = 0;       // wake bouts after onset
        public var epochSec as Lang.Number = 30;

        function initialize(n as Lang.Number) {
            stages = new [n] as Lang.Array<Lang.Number>;
            for (var i = 0; i < n; i++) { stages[i] = 0; }
        }

        // Derived metrics (minutes / percent), computed on demand.
        function tstMin() as Lang.Float { return sleepEpochs * epochSec / 60.0; }
        function solMin() as Lang.Float {
            if (onsetIdx < 0) { return 0.0; }
            return onsetIdx * epochSec / 60.0;
        }
        function wasoMin() as Lang.Float { return wasoEpochs * epochSec / 60.0; }
        // Time in bed = whole logged window (immobility + clock define it here:
        // the session itself is the in-bed window the user declared at bedtime).
        function tibMin() as Lang.Float { return totalEpochs * epochSec / 60.0; }
        function efficiencyPct() as Lang.Float {
            if (totalEpochs == 0) { return 0.0; }
            return 100.0 * sleepEpochs / totalEpochs;
        }
        function pct(c as Lang.Number) as Lang.Float {
            if (sleepEpochs == 0) { return 0.0; }
            return 100.0 * c / sleepEpochs;
        }
    }

    // Main entry: classify and compute metrics.
    function analyze(
        move as Lang.Array<Lang.Numeric>,
        hr as Lang.Array<Lang.Numeric>,
        rmssd as Lang.Array<Lang.Numeric>,
        resp as Lang.Array<Lang.Numeric>,
        restingHr as Lang.Number,
        epochSec as Lang.Number
    ) as StageResult {

        var n = move.size();
        var res = new StageResult(n);
        res.totalEpochs = n;
        res.epochSec = epochSec;
        if (n == 0) { return res; }

        // --- Pass 0: nightly references for relative thresholds. ---
        var hrNadir = 9999;
        var rmssdSum = 0.0; var rmssdCnt = 0;
        var respMean = 0.0; var respCnt = 0;
        for (var i = 0; i < n; i++) {
            if (hr[i] > 0 && hr[i] < hrNadir) { hrNadir = hr[i]; }
            if (rmssd[i] > 0) { rmssdSum += rmssd[i]; rmssdCnt += 1; }
            if (resp[i] > 0) { respMean += resp[i]; respCnt += 1; }
        }
        if (hrNadir == 9999) { hrNadir = restingHr; }
        var rmssdMean = (rmssdCnt > 0) ? rmssdSum / rmssdCnt : 0.0;
        respMean = (respCnt > 0) ? respMean / respCnt : 15.0;

        // --- Pass 1: binary sleep/wake by movement + dHR. ---
        var sw = new [n] as Lang.Array<Lang.Boolean>;   // true = asleep candidate
        for (var i = 0; i < n; i++) {
            var dHr = hr[i] - restingHr;
            var moving = move[i] > MOVE_WAKE;
            var wake = moving || (dHr > 12 && move[i] > MOVE_QUIET);
            sw[i] = !wake;
        }

        // --- Pass 2: immobility rule for onset/offset. ---
        // Sleep onset = first run of >=ONSET_RUN consecutive sleep epochs
        // (allow 1 active epoch inside the run). final wake = last sleep epoch.
        var ONSET_RUN = 20;  // 20 * 30 s = 10 min
        var onset = -1;
        var run = 0; var allow = 1;
        for (var i = 0; i < n; i++) {
            if (sw[i]) {
                run += 1;
            } else if (allow > 0 && run > 0) {
                allow -= 1; run += 1;
            } else {
                run = 0; allow = 1;
            }
            if (run >= ONSET_RUN) { onset = i - run + 1; break; }
        }
        if (onset < 0) {
            // Never reached a sustained block: take first sleep epoch if any.
            for (var i = 0; i < n; i++) { if (sw[i]) { onset = i; break; } }
        }
        var finalSleep = -1;
        for (var i = n - 1; i >= 0; i--) { if (sw[i]) { finalSleep = i; break; } }
        res.onsetIdx = onset;
        res.finalWakeIdx = finalSleep;

        // --- Pass 3: within-sleep stage assignment. ---
        for (var i = 0; i < n; i++) {
            var stage = WAKE;
            var inPeriod = (onset >= 0 && i >= onset && finalSleep >= 0 && i <= finalSleep);
            if (sw[i] && inPeriod) {
                var t = i.toFloat() / n;     // fraction of night elapsed
                var dHr = hr[i] - restingHr;
                var rmssdHigh = (rmssd[i] > 0) && (rmssd[i] >= rmssdMean * 1.1);
                var rmssdLow  = (rmssd[i] > 0) && (rmssd[i] <= rmssdMean * 0.85);
                var hrLow = (hr[i] > 0) && (hr[i] <= hrNadir + 3);
                var slowRegResp = (resp[i] > 0) && (resp[i] <= respMean) && (resp[i] > 0);
                var irregResp = (resp[i] > 0) && (resp[i] >= respMean + 1);
                var still = move[i] < MOVE_QUIET;

                if (hrLow && rmssdHigh && slowRegResp && still) {
                    stage = DEEP;
                } else if (rmssdLow && (dHr > 3) && irregResp && still && t > 0.4) {
                    stage = REM;
                } else {
                    stage = LIGHT;
                }
            } else if (sw[i]) {
                // Asleep candidate but outside the bounded sleep period -> WAKE.
                stage = WAKE;
            } else {
                stage = WAKE;
            }
            res.stages[i] = stage;
        }

        // --- Pass 4: smooth single-epoch flips (median-ish of width 3). ---
        smooth(res.stages);

        // --- Pass 5: tally metrics from the final series. ---
        var prevWake = false;
        for (var i = 0; i < n; i++) {
            var st = res.stages[i];
            if (st == WAKE) {
                res.wakeEpochs += 1;
                var inPeriod = (onset >= 0 && i >= onset && finalSleep >= 0 && i <= finalSleep);
                if (inPeriod) {
                    res.wasoEpochs += 1;
                    if (!prevWake) { res.awakenings += 1; }
                }
                prevWake = true;
            } else {
                if (st == LIGHT) { res.lightEpochs += 1; }
                else if (st == DEEP) { res.deepEpochs += 1; }
                else if (st == REM) { res.remEpochs += 1; }
                res.sleepEpochs += 1;
                prevWake = false;
            }
        }
        return res;
    }

    // Replace isolated single-epoch flips with their neighbors' value.
    function smooth(stages as Lang.Array<Lang.Number>) as Void {
        var n = stages.size();
        if (n < 3) { return; }
        var copy = new [n] as Lang.Array<Lang.Number>;
        for (var i = 0; i < n; i++) { copy[i] = stages[i]; }
        for (var i = 1; i < n - 1; i++) {
            if (copy[i - 1] == copy[i + 1] && copy[i] != copy[i - 1]) {
                stages[i] = copy[i - 1];
            }
        }
    }

    // Single-character glyph for a stage (for the text hypnogram).
    function glyph(st as Lang.Number) as Lang.String {
        if (st == WAKE) { return "W"; }
        if (st == LIGHT) { return "L"; }
        if (st == DEEP) { return "D"; }
        return "R";
    }
}
