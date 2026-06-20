import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;

// The watch face. Reads user settings each draw and renders either a digital or
// an analog layout, with a stripped-down look in always-on (low-power) mode to
// protect the Venu 3's AMOLED screen.
class VenuWatchFaceView extends WatchUi.WatchFace {

    // Justify text to the center both horizontally and vertically.
    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // True while the watch is awake (high-power). In low power we draw less.
    private var _isAwake as Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    // While awake this is called ~once per second; in low-power once per minute.
    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;

        // Read user settings (with safe fallbacks).
        var faceStyle  = getNumberSetting("FaceStyle", 0);
        var accent     = resolveAccent(getNumberSetting("AccentColor", 0));
        var showSecond = getBoolSetting("ShowSeconds", true);
        var showSteps  = getBoolSetting("ShowSteps", true);
        var showBattery= getBoolSetting("ShowBattery", true);
        var lowPower   = !_isAwake;

        // Black background — essential for AMOLED battery life and always-on.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (faceStyle == 1) {
            drawAnalog(dc, cx, cy, accent, showSecond, lowPower);
        } else {
            drawDigital(dc, cx, cy, height, accent, showSecond, showSteps, showBattery, lowPower);
        }
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    // ---------------------------------------------------------------- DIGITAL

    private function drawDigital(dc as Dc, cx as Number, cy as Number, height as Number,
            accent as Number, showSecond as Boolean, showSteps as Boolean,
            showBattery as Boolean, lowPower as Boolean) as Void {

        // Date
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$, $2$ $3$", [now.day_of_week, now.month, now.day.format("%d")]);
        dc.setColor(lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.22).toNumber(), Graphics.FONT_SMALL, dateStr, CENTER);

        // Time (HH:MM)
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeStr = Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);
        dc.setColor(lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_THAI_HOT, timeStr, CENTER);

        // In always-on mode, stop here to keep lit pixels to a minimum.
        if (lowPower) {
            return;
        }

        // Seconds (only ticks while awake)
        if (showSecond) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (height * 0.13).toNumber(), Graphics.FONT_SMALL,
                clock.sec.format("%02d"), CENTER);
        }

        // Battery
        if (showBattery) {
            var battery = System.getSystemStats().battery;
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (height * 0.22).toNumber(), Graphics.FONT_SMALL,
                battery.toNumber().format("%d") + "%", CENTER);
        }

        // Steps
        if (showSteps) {
            var info = ActivityMonitor.getInfo();
            var steps = (info.steps == null) ? 0 : info.steps;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (height * 0.30).toNumber(), Graphics.FONT_TINY,
                steps.format("%d") + " steps", CENTER);
        }
    }

    // ----------------------------------------------------------------- ANALOG

    private function drawAnalog(dc as Dc, cx as Number, cy as Number, accent as Number,
            showSecond as Boolean, lowPower as Boolean) as Void {

        var radius = (cx < cy) ? cx : cy;
        var clock = System.getClockTime();

        // Tick marks (skipped in always-on mode to save pixels)
        if (!lowPower) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var i = 0; i < 12; i += 1) {
                var a = i * (Math.PI / 6.0);
                drawTick(dc, cx, cy, a, radius - 6, radius - 18);
            }
        }

        // Hour hand
        var hourAngle = ((clock.hour % 12) + clock.min / 60.0) * (Math.PI / 6.0);
        dc.setColor(lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(lowPower ? 3 : 6);
        drawHand(dc, cx, cy, hourAngle, radius * 0.5);

        // Minute hand
        var minAngle = clock.min * (Math.PI / 30.0);
        dc.setColor(lowPower ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(lowPower ? 2 : 4);
        drawHand(dc, cx, cy, minAngle, radius * 0.8);

        // Second hand (only while awake)
        if (!lowPower && showSecond) {
            var secAngle = clock.sec * (Math.PI / 30.0);
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            drawHand(dc, cx, cy, secAngle, radius * 0.85);
        }

        // Center hub
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, lowPower ? 3 : 5);
    }

    // Draw a line from the center outward at `angle` (0 = 12 o'clock).
    private function drawHand(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float) as Void {
        var x = cx + length * Math.sin(angle);
        var y = cy - length * Math.cos(angle);
        dc.drawLine(cx, cy, x, y);
    }

    // Draw a tick mark between two radii at `angle`.
    private function drawTick(dc as Dc, cx as Number, cy as Number, angle as Float, outer as Number, inner as Number) as Void {
        var x1 = cx + outer * Math.sin(angle);
        var y1 = cy - outer * Math.cos(angle);
        var x2 = cx + inner * Math.sin(angle);
        var y2 = cy - inner * Math.cos(angle);
        dc.drawLine(x1, y1, x2, y2);
    }

    // ---------------------------------------------------------------- HELPERS

    private function resolveAccent(idx as Number) as Number {
        switch (idx) {
            case 1:  return Graphics.COLOR_BLUE;
            case 2:  return Graphics.COLOR_GREEN;
            case 3:  return Graphics.COLOR_ORANGE;
            case 4:  return Graphics.COLOR_RED;
            default: return Graphics.COLOR_WHITE;
        }
    }

    private function getNumberSetting(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v == null) { return def; }
        return v as Number;
    }

    private function getBoolSetting(key as String, def as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        if (v == null) { return def; }
        return v as Boolean;
    }
}
