import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. Returns a View + an input delegate (so the app responds to
// taps / buttons), unlike a watch face which returns only a View.
class NudgeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new NudgeView();
        return [ view, new NudgeDelegate(view) ];
    }
}
