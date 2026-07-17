import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point. Its name ("SleepLoggerApp") matches the "entry"
// attribute in manifest.xml.
//
// Architecture (foreground, not background):
//   - Connect IQ background temporal events fire at a ~5 min minimum interval,
//     which is far too coarse for 30 s actigraphy epochs. So the whole session
//     runs in the foreground: the user starts logging at bedtime and the app
//     stays alive overnight, driven by a 30 s Timer.
//   - Each epoch the Engine appends a compact numeric record (movement index,
//     mean HR, RMSSD, respiration, epoch index) to Application.Storage.
//   - On "Stop / Wake" the Staging module classifies every epoch and the
//     results view shows TST, efficiency, onset latency, WASO, awakenings,
//     stage % and a text hypnogram.
class SleepLoggerApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        // Belt-and-suspenders: never leave the high-rate stream running if the
        // app is killed while a session is active.
        SensorData.stopStreaming();
    }

    // Return the start/status view + its behavior delegate.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var engine = new SleepEngine();
        var view = new StartView(engine);
        var delegate = new StartDelegate(view, engine);
        return [ view, delegate ];
    }
}
