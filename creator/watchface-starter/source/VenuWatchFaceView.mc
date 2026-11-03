import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;

// The watch face. Reads user settings each draw and renders either a digital or
// an analog layout, with a stripped-down look in always-on (low-power) mode to
// protect the Venu 3's AMOLED screen.
class VenuWatchFaceView extends WatchUi.WatchFace {

    // Justify text to the center both horizontally and vertically.
    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    private const GOLD = 0xD4AF37;     // title + date border

    // Sweep frame interval: ~20 steps a second. Raise it if the watch can't keep up.
    private const FRAME_MS = 50;

    // True while the watch is awake (high-power). In low power we draw less.
    private var _isAwake as Boolean = true;

    private var _timer as Timer.Timer?;              // drives the sweep while awake
    private var _layer as BufferedBitmapReference?;  // everything except the seconds hand
    private var _layerSec as Number = -1;            // the second _layer was drawn for
    private var _lastSec as Number = -1;
    private var _secStartMs as Number = 0;           // System.getTimer() when the second changed

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    // The system calls this ~once per second while awake and once per minute in
    // low power; while awake the sweep timer also calls it every FRAME_MS.
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

        // Watch faces may only animate while awake, so the sweep runs only then.
        if (!lowPower && faceStyle == 1 && showSecond) {
            if (_timer == null) {
                var t = new Timer.Timer();
                t.start(method(:onFrame), FRAME_MS, true);
                _timer = t;
            }
        } else {
            stopSweep();
        }

        if (faceStyle == 1) {
            drawAnalog(dc, cx, cy, showSecond, lowPower);
            return;
        }

        // Black background — essential for AMOLED battery life and always-on.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        drawDigital(dc, cx, cy, height, accent, showSecond, showSteps, showBattery, lowPower);
    }

    function onFrame() as Void {
        WatchUi.requestUpdate();
    }

    private function stopSweep() as Void {
        var t = _timer;
        if (t != null) {
            t.stop();
            _timer = null;
        }
    }

    function onHide() as Void {
        stopSweep();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        stopSweep();
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

    private function drawAnalog(dc as Dc, cx as Number, cy as Number,
            showSecond as Boolean, lowPower as Boolean) as Void {

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);   // smooth, non-jagged edges
        }
        var radius = (cx < cy) ? cx : cy;
        var clock = System.getClockTime();
        // [light, dark] metal for every hand and the cap, from the Hand Color setting.
        var tones = handTones(getNumberSetting("HandColor", 4));

        // Always-on: the same face minus the seconds hand (the watch redraws only once a
        // minute here, so it would sit frozen). Nudged 2 px each minute in a square so no
        // pixel stays lit for long (AMOLED burn-in rule).
        if (lowPower) {
            var step = clock.min % 4;
            var ox = (step == 1 || step == 2) ? 2 : 0;
            var oy = (step >= 2) ? 2 : 0;
            drawStatic(dc, cx + ox, cy + oy, radius, clock, tones);
            drawCap(dc, cx + ox, cy + oy, tones);
            return;
        }

        // Everything but the seconds hand changes at most once a second, so it is drawn
        // into an offscreen layer once and copied on every sweep frame.
        var layer = getLayer(dc);
        if (layer == null) {
            drawStatic(dc, cx, cy, radius, clock, tones);
        } else {
            if (_layerSec != clock.sec) {
                var ldc = layer.getDc();
                if (ldc has :setAntiAlias) { ldc.setAntiAlias(true); }
                drawStatic(ldc, cx, cy, radius, clock, tones);
                _layerSec = clock.sec;
            }
            dc.drawBitmap(0, 0, layer);
        }

        if (showSecond) {
            var nowMs = System.getTimer();
            if (clock.sec != _lastSec) {
                _lastSec = clock.sec;
                _secStartMs = nowMs;
            }
            var sec = clock.sec + secFraction(nowMs, _secStartMs);
            drawSecondsHand(dc, cx, cy, radius, sec * (Math.PI / 30.0), tones[0], tones[1]);
        }

        drawCap(dc, cx, cy, tones);
    }

    // Centre cap over the hands, in the hands' metal: ring, polished cap, dark pin.
    private function drawCap(dc as Dc, x as Number, y as Number, tones as Array<Number>) as Void {
        dc.setColor(mixColor(tones[1], tones[0], 0.5), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
        dc.setColor(mixColor(tones[1], tones[0], 0.88), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 3);
        dc.setColor(mixColor(0x000000, tones[1], 0.45), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 1);
    }

    // The offscreen layer lives in the graphics pool, which may purge it; recreate on demand.
    private function getLayer(dc as Dc) as BufferedBitmap? {
        var ref = _layer;
        var bmp = (ref != null) ? ref.get() : null;
        if (bmp == null && (Graphics has :createBufferedBitmap)) {
            ref = Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight()});
            _layer = ref;
            _layerSec = -1;
            bmp = ref.get();
        }
        return bmp as BufferedBitmap?;
    }

    // Black dial, title, date window, hour + minute hands.
    private function drawStatic(dc as Dc, cx as Number, cy as Number, radius as Number,
            clock as System.ClockTime, tones as Array<Number>) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var markers = getBoolSetting("HourMarkers", false);
        if (markers) {
            drawMarkers(dc, cx, cy, radius, tones);
        }

        // Custom title near the top — text, size and visibility all from settings.
        if (getBoolSetting("ShowTitle", true)) {
            var title = getStringSetting("Title", "B H U V I");
            var nameY = cy - (radius * (markers ? 0.52 : 0.80)).toNumber();   // under the 12 baton
            var titleSize = getNumberSetting("TitleSize", 18);
            if (titleSize < 8)  { titleSize = 8; }
            if (titleSize > 40) { titleSize = 40; }
            var nameFont = Graphics.getVectorFont({:face => "RobotoRegular", :size => titleSize});
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            if (nameFont != null) {
                dc.drawText(cx, nameY, nameFont, title, CENTER);
            } else {
                dc.drawText(cx, nameY, Graphics.FONT_XTINY, title, CENTER);
            }
        }

        // Date window — toggle-able.
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var compH = 38;

        // Date number window at 3 o'clock.
        if (getBoolSetting("ShowDate", true)) {
            var dateNum = now.day.format("%02d");
            var dateFont = Graphics.getVectorFont({:face => "RobotoRegular", :size => 26});
            if (dateFont == null) { dateFont = Graphics.FONT_MEDIUM; }
            var dateCX = cx + (radius * 0.60).toNumber();
            drawWindow(dc, dateCX, cy, 44, compH, dateNum, dateFont, getNumberSetting("DateStyle", 0), tones);
        }

        if (getBoolSetting("BatteryReserve", false)) {
            drawReserve(dc, cx, cy, radius, tones);
        }

        drawHands(dc, cx, cy, radius, clock, tones[0], tones[1]);
    }

    // Date Style: 0 classic gold frame, 1 steel bevel, 2 white date wheel, 3 frameless.
    private function drawWindow(dc as Dc, x as Number, y as Number, w as Number, h as Number,
            text as String, font as FontType, style as Number, tones as Array<Number>) as Void {
        var light = tones[0];
        var dark = tones[1];
        var ink = Graphics.COLOR_WHITE;
        var l = x - w / 2;
        var t = y - h / 2;
        if (style == 1) {
            // Faceted frame in the hands' metal: lit top-left edge, shaded bottom-right edge.
            dc.setColor(mixColor(dark, light, 0.35), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(l - 2, t - 2, w + 4, h + 4, 3);
            dc.setColor(mixColor(dark, light, 0.95), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[l - 2, t + h + 2], [l - 2, t - 2], [l + w + 2, t - 2],
                [l + w - 2, t + 2], [l + 2, t + 2], [l + 2, t + h - 2]]);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(l + 2, t + 2, w - 4, h - 4);
        } else if (style == 2) {
            // White date wheel behind a thin polished frame.
            dc.setColor(mixColor(dark, light, 0.6), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(l - 1, t - 1, w + 2, h + 2, 3);
            dc.setColor(0xF2F1EC, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(l + 2, t + 2, w - 4, h - 4);
            ink = 0x111111;
        } else if (style != 3) {
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawRoundedRectangle(l, t, w, h, 4);
        }
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, CENTER);
    }

    // Slim faceted batons in the hands' metal, doubled at 12; the 3 starts outside the date.
    private function drawMarkers(dc as Dc, cx as Number, cy as Number, radius as Number,
            tones as Array<Number>) as Void {
        for (var h = 0; h < 12; h++) {
            var a = h * Math.PI / 6.0;
            if (h == 0) {
                drawBaton(dc, cx, cy, a - 0.03, radius * 0.70, radius * 0.93, radius * 0.017, tones);
                drawBaton(dc, cx, cy, a + 0.03, radius * 0.70, radius * 0.93, radius * 0.017, tones);
            } else {
                drawBaton(dc, cx, cy, a, radius * ((h == 3) ? 0.76 : 0.72), radius * 0.93, radius * 0.016, tones);
            }
        }
    }

    // One baton: two halves split along its length, lit like the hands.
    private function drawBaton(dc as Dc, cx as Number, cy as Number, angle as Numeric,
            r0 as Numeric, r1 as Numeric, hw as Numeric, tones as Array<Number>) as Void {
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var k = facetShade(angle.toFloat());
        for (var side = 1; side >= -1; side -= 2) {
            dc.setColor(mixColor(tones[1], tones[0], (side == 1) ? k : 1.0 - k), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                handPt(cx, cy, dx, dy, r0, 0.0),
                handPt(cx, cy, dx, dy, r1, 0.0),
                handPt(cx, cy, dx, dy, r1, hw * side),
                handPt(cx, cy, dx, dy, r0, hw * side)
            ]);
        }
    }

    // Battery "power reserve": a small arc on its own pivot below the centre (between 7
    // and 8), the hand running from empty (down-left) to full (upper left), plus the
    // watch's own estimate of hours left.
    private function drawReserve(dc as Dc, cx as Number, cy as Number, radius as Number,
            tones as Array<Number>) as Void {
        var stats = System.getSystemStats();
        var px = cx;
        var py = cy + (radius * 0.36).toNumber();
        var r = radius * 0.19;

        // Arc + ticks. drawArc counts degrees anticlockwise from 3 o'clock: 200..300 on the
        // clock face is 250 -> 150 clockwise.
        dc.setColor(mixColor(tones[1], tones[0], 0.45), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(px, py, r.toNumber(), Graphics.ARC_CLOCKWISE, 250, 150);
        for (var i = 0; i <= 8; i++) {
            var a = reserveAngle(i * 12.5);
            var dx = Math.sin(a);
            var dy = -Math.cos(a);
            var len = (i % 4 == 0) ? 7 : 4;
            dc.setPenWidth((i % 4 == 0) ? 2 : 1);
            var p0 = handPt(px, py, dx, dy, r + 2, 0.0);
            var p1 = handPt(px, py, dx, dy, r + 2 + len, 0.0);
            dc.drawLine(p0[0], p0[1], p1[0], p1[1]);
        }

        // Faceted hand + pivot.
        var ang = reserveAngle(stats.battery);
        var hx = Math.sin(ang);
        var hy = -Math.cos(ang);
        var k = facetShade(ang);
        for (var side = 1; side >= -1; side -= 2) {
            dc.setColor(mixColor(tones[1], tones[0], (side == 1) ? k : 1.0 - k), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                handPt(px, py, hx, hy, r * 0.92, 0.0),
                handPt(px, py, hx, hy, 0.0, radius * 0.012 * side),
                handPt(px, py, hx, hy, -radius * 0.03, 0.0)
            ]);
        }
        dc.setColor(mixColor(tones[1], tones[0], 0.6), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, 4);

        // Hours left (the watch's estimate), or the plain percentage if it has none.
        var label = stats.battery.toNumber().format("%d") + "%";
        if ((stats has :batteryInDays) && stats.batteryInDays != null) {
            label = (stats.batteryInDays * 24).toNumber().format("%d") + "h";
        }
        var small = Graphics.getVectorFont({:face => "RobotoRegular", :size => 14});
        dc.setColor(0x8E949C, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px + 10, py, (small != null) ? small : Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Hour + minute hands. The minute hand creeps with the seconds, like a real movement.
    // All sizes are fractions of the radius, measured off the reference dial.
    private function drawHands(dc as Dc, cx as Number, cy as Number, radius as Number,
            clock as System.ClockTime, light as Number, dark as Number) as Void {
        var min = clock.min + clock.sec / 60.0;
        var hourAngle = ((clock.hour % 12) + min / 60.0) * (Math.PI / 6.0);
        drawBladeHand(dc, cx, cy, hourAngle, radius * 0.618, radius * 0.037, radius * 0.025, 0.75,
            radius * 0.217, light, dark);
        drawBladeHand(dc, cx, cy, min * (Math.PI / 30.0), radius * 0.948, radius * 0.034, radius * 0.016, 0.855,
            radius * 0.205, light, dark);
        dc.setColor(mixColor(dark, light, 0.7), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6);
    }

    // Sharp-edged blade hand: widest at the centre and tapering to a two-facet spear
    // point, with a flat polished top between two bevels and a short pointed tail. The
    // bevel facing the light (upper left) is bright, the other grey; they swap as it turns.
    private function drawBladeHand(dc as Dc, cx as Number, cy as Number, angle as Float,
            length as Float, hubW as Float, pointW as Float, pointFrac as Float, tail as Float,
            light as Number, dark as Number) as Void {
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var k = facetShade(angle);
        var pointAt = length * pointFrac;   // where the spear point begins
        var tip = handPt(cx, cy, dx, dy, length, 0.0);
        var root = handPt(cx, cy, dx, dy, -tail, 0.0);

        for (var side = 1; side >= -1; side -= 2) {
            dc.setColor(mixColor(dark, light, (side == 1) ? k : 1.0 - k), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                tip,
                handPt(cx, cy, dx, dy, pointAt, pointW * side),
                handPt(cx, cy, dx, dy, 0.0, hubW * side),
                handPt(cx, cy, dx, dy, -tail * 0.45, hubW * 0.85 * side),
                root
            ]);
        }

        // Flat polished top, 42% of the local width, stopping where the point begins.
        var start = length * 0.10;
        var startW = (hubW + (pointW - hubW) * start / pointAt) * 0.42;
        dc.setColor(mixColor(dark, light, 0.88), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            handPt(cx, cy, dx, dy, start, startW),
            handPt(cx, cy, dx, dy, pointAt, pointW * 0.42),
            handPt(cx, cy, dx, dy, pointAt, -pointW * 0.42),
            handPt(cx, cy, dx, dy, start, -startW)
        ]);

        // Ridge down the point.
        var ridge = handPt(cx, cy, dx, dy, pointAt, 0.0);
        dc.setColor(mixColor(0x000000, dark, 0.65), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(ridge[0], ridge[1], tip[0], tip[1]);
    }

    // Thin needle with a broad faceted counterweight, in the hands' metal.
    private function drawSecondsHand(dc as Dc, cx as Number, cy as Number, radius as Number,
            angle as Float, light as Number, dark as Number) as Void {
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var len = radius * 0.972;
        var tail = radius * 0.347;
        var w = radius * 0.025;
        var k = facetShade(angle);

        dc.setColor(mixColor(dark, light, 0.5), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            handPt(cx, cy, dx, dy, len, radius * 0.006),
            handPt(cx, cy, dx, dy, len, -radius * 0.006),
            handPt(cx, cy, dx, dy, 0.0, -radius * 0.0095),
            handPt(cx, cy, dx, dy, 0.0, radius * 0.0095)
        ]);
        for (var side = 1; side >= -1; side -= 2) {
            dc.setColor(mixColor(dark, light, (side == 1) ? k : 1.0 - k), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                handPt(cx, cy, dx, dy, 0.0, 0.0),
                handPt(cx, cy, dx, dy, 0.0, w * 0.5 * side),
                handPt(cx, cy, dx, dy, -radius * 0.08, w * side),
                handPt(cx, cy, dx, dy, -tail * 0.92, w * side),
                handPt(cx, cy, dx, dy, -tail, 0.0)
            ]);
        }
    }

    // Point t along the hand from the centre and w across it (positive = clockwise side).
    private function handPt(cx as Number, cy as Number, dx as Numeric, dy as Numeric,
            t as Numeric, w as Numeric) as Point2D {
        return [cx + t * dx - w * dy, cy + t * dy + w * dx];
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

    // [light facet, dark facet] per Hand Color: 0 Ivory, 1 Gold, 2 White, 3 Rose Gold, 4 Silver.
    private function handTones(idx as Number) as Array<Number> {
        switch (idx) {
            case 0:  return [0xF4EEDF, 0x8C846F];
            case 1:  return [0xF5DD96, 0x8F6C27];
            case 2:  return [0xFFFFFF, 0x9A9DA3];
            case 3:  return [0xF2C6B8, 0x8A5246];
            default: return [0xF3F4F5, 0x7D8085];   // neutral steel
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
