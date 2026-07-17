using Toybox.WatchUi;
using Toybox.Lang;

// Behavior for the results screen: page up/down, BACK pops to start.
class ResultsDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Lang.Boolean { return flip(1); }
    function onPreviousPage() as Lang.Boolean { return flip(-1); }

    function onKey(evt as WatchUi.KeyEvent) as Lang.Boolean {
        var k = evt.getKey();
        if (k == WatchUi.KEY_DOWN) { return flip(1); }
        if (k == WatchUi.KEY_UP)   { return flip(-1); }
        return false;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Lang.Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP)   { return flip(1); }
        if (d == WatchUi.SWIPE_DOWN) { return flip(-1); }
        return false;
    }

    private function flip(dir as Lang.Number) as Lang.Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof ResultsView) {
            var p = view.page + dir;
            if (p < 0) { p = 0; }
            if (p >= view.PAGES) { p = view.PAGES - 1; }
            view.page = p;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
