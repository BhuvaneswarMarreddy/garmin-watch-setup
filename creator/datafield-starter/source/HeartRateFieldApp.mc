import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. Name must match the "entry" attribute in manifest.xml.
class HeartRateFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // The single view shown in the activity's data box.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new HeartRateFieldView() ];
    }
}
