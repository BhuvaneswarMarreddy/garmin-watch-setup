import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The application entry point. Its name ("VenuWatchFaceApp") must match the
// "entry" attribute in manifest.xml.
class VenuWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the first (and only) view — the watch face.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new VenuWatchFaceView() ];
    }

    // Called when the user changes settings in the Garmin Connect app.
    // Redraw so the new theme / toggles take effect immediately.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
