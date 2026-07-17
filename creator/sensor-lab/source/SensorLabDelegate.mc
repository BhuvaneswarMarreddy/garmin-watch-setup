import Toybox.WatchUi;
import Toybox.Lang;

// Behavior delegate: turns swipe / next-page / previous-page behaviors into
// page changes on the view. Works for both the touch swipe (Venu 3 is a
// touchscreen) and physical page behaviors.
class SensorLabDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SensorLabView;

    function initialize(view as SensorLabView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Lang.Boolean {
        _view.setPage(_view.getPage() + 1);
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        _view.setPage(_view.getPage() - 1);
        return true;
    }

    // Map vertical swipes to page navigation (up = next, down = previous),
    // matching the on-screen "page N/4" advancing.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Lang.Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_LEFT) {
            _view.setPage(_view.getPage() + 1);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN || dir == WatchUi.SWIPE_RIGHT) {
            _view.setPage(_view.getPage() - 1);
            return true;
        }
        return false;
    }
}
