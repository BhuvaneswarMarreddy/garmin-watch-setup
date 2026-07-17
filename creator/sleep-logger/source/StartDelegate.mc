using Toybox.WatchUi;
using Toybox.Lang;

// Behavior for the start/status screen.
//   - START/ENTER toggles the session: start logging, or stop + show results.
class StartDelegate extends WatchUi.BehaviorDelegate {

    private var _view as StartView;
    private var _engine as SleepEngine;

    function initialize(view as StartView, engine as SleepEngine) {
        BehaviorDelegate.initialize();
        _view = view;
        _engine = engine;
    }

    // Physical START button / on-screen tap.
    function onSelect() as Lang.Boolean {
        toggle();
        return true;
    }

    // Some inputs surface as a menu/key event; treat ENTER the same.
    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_ENTER || k == WatchUi.KEY_START) {
            toggle();
            return true;
        }
        return false;
    }

    function onTap(evt as WatchUi.ClickEvent) as Lang.Boolean {
        toggle();
        return true;
    }

    private function toggle() as Void {
        if (_engine.isRunning()) {
            _engine.stop();
            // Run staging and show results.
            var res = Staging.analyze(
                _engine.moveArr as Lang.Array<Lang.Numeric>,
                _engine.hrArr as Lang.Array<Lang.Numeric>,
                _engine.rmssdArr as Lang.Array<Lang.Numeric>,
                _engine.respArr as Lang.Array<Lang.Numeric>,
                _engine.restingHr, _engine.EPOCH_SEC);
            var rv = new ResultsView(res);
            var rd = new ResultsDelegate();
            WatchUi.pushView(rv, rd, WatchUi.SLIDE_LEFT);
        } else {
            _engine.start();
            WatchUi.requestUpdate();
        }
    }
}
