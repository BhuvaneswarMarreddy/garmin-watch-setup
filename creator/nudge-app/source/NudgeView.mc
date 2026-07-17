import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The Nudge screen: a 1-second countdown that fires an alert at zero, plus a
// running count of how many nudges have fired. The delegate drives the buttons.
class NudgeView extends WatchUi.View {

    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    private var _intervalSec as Number = 60;   // nudge every 60s
    private var _remaining as Number = 60;
    private var _count as Number = 0;
    private var _running as Boolean = true;
    private var _timer as Timer.Timer or Null = null;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _remaining = _intervalSec;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);   // tick once per second
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // Called every second by the timer.
    function onTick() as Void {
        if (_running) {
            _remaining -= 1;
            if (_remaining <= 0) {
                _count += 1;
                _remaining = _intervalSec;
                nudge("Time to move!");
            }
        }
        WatchUi.requestUpdate();
    }

    // The "notification": grab attention with every channel the watch has.
    function nudge(message as String) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(75, 600)] as Array<Attention.VibeProfile>);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_LOUD_BEEP);
        }
        if (Attention has :backlight) {
            Attention.backlight(true);
        }
        if (WatchUi has :showToast) {
            WatchUi.showToast(message, null);
        }
    }

    function togglePause() as Void {
        _running = !_running;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (h * 0.30).toNumber(), Graphics.FONT_SMALL, "NUDGE", CENTER);

        // Big countdown (or "paused").
        var label = _running ? (_remaining.format("%d") + "s") : "paused";
        dc.setColor(_running ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, label, CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (h * 0.24).toNumber(), Graphics.FONT_TINY,
            "nudges: " + _count.format("%d"), CENTER);
        dc.drawText(cx, cy + (h * 0.36).toNumber(), Graphics.FONT_XTINY,
            "tap = test   menu = pause", CENTER);
    }
}
