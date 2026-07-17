using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

// Start / status screen. Before the session it invites the user to start
// logging; while running it shows elapsed time and epoch count.
class StartView extends WatchUi.View {

    private var _engine as SleepEngine;

    function initialize(engine as SleepEngine) {
        View.initialize();
        _engine = engine;
    }

    function onLayout(dc as Graphics.Dc) as Void {}

    function onShow() as Void {}

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.18, Graphics.FONT_SMALL, "Sleep Logger",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (_engine.isRunning()) {
            var sec = _engine.elapsedSec();
            var hh = sec / 3600;
            var mm = (sec % 3600) / 60;
            var ss = sec % 60;
            var t = hh.format("%d") + ":" + mm.format("%02d") + ":" + ss.format("%02d");
            dc.drawText(cx, h * 0.42, Graphics.FONT_NUMBER_MEDIUM, t,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, h * 0.60, Graphics.FONT_TINY,
                        "Logging  " + _engine.epochCount.format("%d") + " epochs",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.80, Graphics.FONT_TINY, "START = Stop / Wake",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.drawText(cx, h * 0.45, Graphics.FONT_SMALL, "Start sleep logging",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.68, Graphics.FONT_TINY, "Press START at bedtime",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function onHide() as Void {}
}
