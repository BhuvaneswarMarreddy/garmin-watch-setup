import Toybox.Lang;
import Toybox.WatchUi;

// Handles user input. A watch app needs a BehaviorDelegate to react to the
// physical buttons and screen taps (a watch face has no input delegate).
class NudgeDelegate extends WatchUi.BehaviorDelegate {

    private var _view as NudgeView;

    function initialize(view as NudgeView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Physical Start/Select button → fire a test alert immediately.
    function onSelect() as Boolean {
        _view.nudge("Test nudge");
        return true;
    }

    // Screen tap (touchscreen) → also fire a test alert.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.nudge("Test nudge");
        return true;
    }

    // Menu action → pause / resume the countdown.
    function onMenu() as Boolean {
        _view.togglePause();
        return true;
    }

    // Back → let the system close the app.
    function onBack() as Boolean {
        return false;
    }
}
