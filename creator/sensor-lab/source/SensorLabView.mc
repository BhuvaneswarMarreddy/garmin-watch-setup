import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.System;

// The single paged view. The current page index is owned here; the delegate
// flips it and asks for a redraw. A 1-second timer keeps live values fresh,
// and the raw accelerometer/gyro/mag stream runs only while the Motion page
// is visible (started in onShow, stopped in onHide).
class SensorLabView extends WatchUi.View {

    public const PAGE_COUNT = 4;
    public const PAGE_MOTION = 1; // 0-indexed: Vitals, Motion, Environment, System

    private var _page as Lang.Number = 0;
    private var _timer as Timer.Timer or Null = null;
    private var _streaming as Lang.Boolean = false;

    private var _titles as Lang.Array<Lang.String> = [
        "Vitals",
        "Motion",
        "Environment",
        "System & Profile"
    ];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function getPage() as Lang.Number {
        return _page;
    }

    // Called by the delegate. Manages the accelerometer stream as we move
    // on/off the Motion page so it only runs when needed.
    function setPage(page as Lang.Number) as Void {
        if (page < 0) { page = PAGE_COUNT - 1; }
        if (page >= PAGE_COUNT) { page = 0; }
        if (page == _page) { return; }

        var wasMotion = (_page == PAGE_MOTION);
        var nowMotion = (page == PAGE_MOTION);
        _page = page;

        if (nowMotion && !wasMotion) {
            startMotionStream();
        } else if (wasMotion && !nowMotion) {
            stopMotionStream();
        }
        WatchUi.requestUpdate();
    }

    private function startMotionStream() as Void {
        if (!_streaming) {
            SensorData.startStreaming();
            _streaming = true;
        }
    }

    private function stopMotionStream() as Void {
        if (_streaming) {
            SensorData.stopStreaming();
            _streaming = false;
        }
    }

    function onShow() as Void {
        // 1-second refresh for live values.
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        _timer.start(method(:onTick), 1000, true);

        if (_page == PAGE_MOTION) {
            startMotionStream();
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
        stopMotionStream();
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    private function currentReads() as Lang.Array<Lang.Array<Lang.String>> {
        if (_page == 0) {
            return SensorData.readVitals();
        } else if (_page == 1) {
            return SensorData.readMotion();
        } else if (_page == 2) {
            return SensorData.readEnvironment();
        } else {
            return SensorData.readSystem();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Black background.
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // --- Header: title + page indicator ---
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var title = _titles[_page];
        dc.drawText(w / 2, h * 0.085, Graphics.FONT_SMALL, title,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.15, Graphics.FONT_XTINY,
                    "page " + (_page + 1).toString() + "/" + PAGE_COUNT.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- Body: label/value rows ---
        var reads = currentReads();
        var rows = reads.size();

        // Layout the rows within the central band of the round screen so they
        // stay clear of the curved top/bottom edges.
        var top = h * 0.22;
        var bottom = h * 0.90;
        var band = bottom - top;
        var rowH = (rows > 0) ? (band / rows) : band;

        var labelX = w * 0.12;
        var valueX = w * 0.88;
        var font = (rowH < 28) ? Graphics.FONT_XTINY : Graphics.FONT_TINY;

        for (var i = 0; i < rows; i++) {
            var pair = reads[i];
            var label = pair[0] as Lang.String;
            var value = pair[1] as Lang.String;
            var y = top + rowH * i + rowH / 2;

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(labelX, y, font, label,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(valueX, y, font, value,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
