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
            var stepCount = info.steps;
            var stepsText = "0";
            if (stepCount != null) {
                stepsText = stepCount.format("%d");
            }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (height * 0.30).toNumber(), Graphics.FONT_TINY,
                stepsText + " steps", CENTER);
        }
    }

    // ----------------------------------------------------------------- ANALOG

    private function drawAnalog(dc as Dc, cx as Number, cy as Number, accent as Number,
            showSecond as Boolean, lowPower as Boolean) as Void {

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);   // smooth, non-jagged hand edges
        }

        var radius = (cx < cy) ? cx : cy;
        var clock = System.getClockTime();
        var hourAngle = ((clock.hour % 12) + clock.min / 60.0) * (Math.PI / 6.0);
        var minAngle  = clock.min * (Math.PI / 30.0);

        // Hand style + colour from settings.
        var filled = (getNumberSetting("HandStyle", 0) == 1);
        var handColor = resolveHandColor(getNumberSetting("HandColor", 0));

        // Always-on mode: SAME hands and size as awake, just dimmed to grey
        // (the slim shape keeps lit pixels low, which suits the AMOLED).
        if (lowPower) {
            drawStyledHand(dc, cx, cy, hourAngle, radius * 0.50, radius * 0.12, 0.40, 7, Graphics.COLOR_LT_GRAY, filled);
            drawStyledHand(dc, cx, cy, minAngle,  radius * 0.80, radius * 0.12, 0.40, 6, Graphics.COLOR_LT_GRAY, filled);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, 4);
            return;
        }

        // Custom title near the top — text, size and visibility all from settings.
        if (getBoolSetting("ShowTitle", true)) {
            var title = getStringSetting("Title", "B H U V I");
            var nameY = cy - (radius * 0.80).toNumber();
            var titleSize = getNumberSetting("TitleSize", 18);
            if (titleSize < 8)  { titleSize = 8; }
            if (titleSize > 40) { titleSize = 40; }
            var nameFont = Graphics.getVectorFont({:face => "RobotoRegular", :size => titleSize});
            dc.setColor(0xD4AF37, Graphics.COLOR_TRANSPARENT);
            if (nameFont != null) {
                dc.drawText(cx, nameY, nameFont, title, CENTER);
            } else {
                dc.drawText(cx, nameY, Graphics.FONT_XTINY, title, CENTER);
            }
        }

        // Day / date complications (Day-Date style) — each toggle-able.
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var compH = 38;

        // Date number window at 3 o'clock (Rolex Datejust / Cyclops style).
        if (getBoolSetting("ShowDate", true)) {
            var dateNum = now.day.format("%02d");
            var dateFont = Graphics.getVectorFont({:face => "RobotoRegular", :size => 26});
            if (dateFont == null) { dateFont = Graphics.FONT_MEDIUM; }
            var dateCX = cx + (radius * 0.60).toNumber();
            var boxW = 44;
            dc.setColor(0xD4AF37, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(dateCX - boxW / 2, cy - compH / 2, boxW, compH, 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dateCX, cy, dateFont, dateNum, CENTER);
        }

        // Day-of-week window at 9 o'clock.
        if (getBoolSetting("ShowDay", true)) {
            var dayStr = (now.day_of_week as String).toUpper();
            var dayFont = Graphics.getVectorFont({:face => "RobotoRegular", :size => 22});
            if (dayFont == null) { dayFont = Graphics.FONT_SMALL; }
            var dayCX = cx - (radius * 0.60).toNumber();
            var dtw = dc.getTextWidthInPixels(dayStr, dayFont);
            if (dtw <= 0) { dtw = 44; }
            var dayW = dtw + 16;
            dc.setColor(0xD4AF37, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(dayCX - dayW / 2, cy - compH / 2, dayW, compH, 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dayCX, cy, dayFont, dayStr, CENTER);
        }

        // Hour & minute hands — elegant pointed (lance) hands; colour and the
        // Outline/Filled look both come from settings.
        drawStyledHand(dc, cx, cy, hourAngle, radius * 0.50, radius * 0.12, 0.40, 7, handColor, filled);
        drawStyledHand(dc, cx, cy, minAngle,  radius * 0.80, radius * 0.12, 0.40, 6, handColor, filled);

        // Second hand — thin GOLD sweep with a small tail (only if enabled).
        if (showSecond) {
            var secAngle = clock.sec * (Math.PI / 30.0);
            dc.setColor(0xD4AF37, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            drawLineHand(dc, cx, cy, secAngle, radius * 0.85);
            drawLineHand(dc, cx, cy, secAngle + Math.PI, radius * 0.18);
        }

        // Center hub — small gold cap with a black pinhole (simple).
        dc.setColor(0xD4AF37, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
    }

    // Simple, elegant OUTLINED pointed (lance) hand — a thin hollow outline:
    // sharp tip, widest at the shoulder, tapering to a point at the tail.
    private function drawOutlinedHand(dc as Dc, cx as Number, cy as Number, angle as Float,
            length as Float, tail as Float, shoulderFrac as Float, halfWidth as Number,
            color as Number, penW as Number) as Void {
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var px = -dy;   // unit perpendicular to the hand direction
        var py = dx;
        var shoulder = length * shoulderFrac;
        var tipX = cx + length * dx;
        var tipY = cy + length * dy;
        var tailX = cx - tail * dx;
        var tailY = cy - tail * dy;
        var slX = cx + shoulder * dx - halfWidth * px;
        var slY = cy + shoulder * dy - halfWidth * py;
        var srX = cx + shoulder * dx + halfWidth * px;
        var srY = cy + shoulder * dy + halfWidth * py;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penW);
        dc.drawLine(tipX, tipY, srX, srY);   // tip -> right shoulder
        dc.drawLine(srX, srY, tailX, tailY); // right shoulder -> tail
        dc.drawLine(tailX, tailY, slX, slY); // tail -> left shoulder
        dc.drawLine(slX, slY, tipX, tipY);   // left shoulder -> tip
    }

    // Dispatch: draw a hand filled (solid) or outlined, per the Hand Style setting.
    private function drawStyledHand(dc as Dc, cx as Number, cy as Number, angle as Float,
            length as Float, tail as Float, shoulderFrac as Float, halfWidth as Number,
            color as Number, filled as Boolean) as Void {
        if (filled) {
            fillLanceHand(dc, cx, cy, angle, length, tail, shoulderFrac, halfWidth, color);
        } else {
            drawOutlinedHand(dc, cx, cy, angle, length, tail, shoulderFrac, halfWidth, color, 2);
        }
    }

    // Filled (solid) pointed lance hand.
    private function fillLanceHand(dc as Dc, cx as Number, cy as Number, angle as Float,
            length as Float, tail as Float, shoulderFrac as Float, halfWidth as Number,
            color as Number) as Void {
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var px = -dy;
        var py = dx;
        var shoulder = length * shoulderFrac;
        var tipX = cx + length * dx;
        var tipY = cy + length * dy;
        var tailX = cx - tail * dx;
        var tailY = cy - tail * dy;
        var pts = [
            [tipX, tipY],
            [cx + shoulder * dx + halfWidth * px, cy + shoulder * dy + halfWidth * py],
            [tailX, tailY],
            [cx + shoulder * dx - halfWidth * px, cy + shoulder * dy - halfWidth * py]
        ];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    // Simple line from center outward (used for low-power hands + second hand).
    private function drawLineHand(dc as Dc, cx as Number, cy as Number, angle as Float, length as Float) as Void {
        var x = cx + length * Math.sin(angle);
        var y = cy - length * Math.cos(angle);
        dc.drawLine(cx, cy, x, y);
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

    // Hand colour options: 0 Ivory, 1 Gold, 2 White, 3 Rose Gold.
    private function resolveHandColor(idx as Number) as Number {
        switch (idx) {
            case 1:  return 0xD4AF37;            // gold
            case 2:  return Graphics.COLOR_WHITE;
            case 3:  return 0xB76E79;            // rose gold
            default: return 0xEDE6D6;            // ivory
        }
    }

    private function getNumberSetting(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.Number) { return v; }
        return def;
    }

    private function getBoolSetting(key as String, def as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.Boolean) { return v; }
        return def;
    }

    private function getStringSetting(key as String, def as String) as String {
        var v = Application.Properties.getValue(key);
        if (v instanceof Lang.String && (v as String).length() > 0) { return v; }
        return def;
    }
}
