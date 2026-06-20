import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;

// A SimpleDataField lets the system handle the layout — you just set a `label`
// and return a value from compute(). This one shows the current heart rate.
class HeartRateFieldView extends WatchUi.SimpleDataField {

    function initialize() {
        SimpleDataField.initialize();
        // The label shown above the value in the activity data box.
        label = "Heart Rate";
    }

    // Called roughly once per second during an activity. Whatever you return is
    // shown in the field. Return a number, a string, or null.
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        if (info has :currentHeartRate && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        return "--";
    }
}
