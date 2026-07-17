import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point. Its name ("SensorLabApp") matches the "entry"
// attribute in manifest.xml.
class SensorLabApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the paged sensor view + its behavior delegate.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new SensorLabView();
        var delegate = new SensorLabDelegate(view);
        return [ view, delegate ];
    }
}
