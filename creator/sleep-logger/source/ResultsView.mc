using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

// Paged results screen. Page 0 = metrics, page 1 = stage % + hypnogram.
// UP/DOWN flip pages; BACK pops to the start screen.
class ResultsView extends WatchUi.View {

    private var _res as Staging.StageResult;
    public var page as Lang.Number = 0;
    public const PAGES = 2;

    function initialize(res as Staging.StageResult) {
        View.initialize();
        _res = res;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (page == 0) { drawMetrics(dc); }
        else { drawStages(dc); }
    }

    private function line(
        dc as Graphics.Dc,
        cx as Lang.Numeric,
        y as Lang.Numeric,
        font as Graphics.FontType,
        label as Lang.String,
        val as Lang.String,
        col as Graphics.ColorType
    ) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, label + "  " + val,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawMetrics(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.12, Graphics.FONT_TINY, "Sleep Summary",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var f = Graphics.FONT_XTINY;
        var c = Graphics.COLOR_WHITE;
        var y = h * 0.26;
        var dy = h * 0.115;
        line(dc, cx, y,            f, "TST",  fmtMin(_res.tstMin()), c);
        line(dc, cx, y + dy,       f, "Eff",  _res.efficiencyPct().format("%.0f") + "%", c);
        line(dc, cx, y + dy * 2,   f, "SOL",  fmtMin(_res.solMin()), c);
        line(dc, cx, y + dy * 3,   f, "WASO", fmtMin(_res.wasoMin()), c);
        line(dc, cx, y + dy * 4,   f, "Wakes", _res.awakenings.format("%d"), c);
        line(dc, cx, y + dy * 5,   f, "TIB",  fmtMin(_res.tibMin()), Graphics.COLOR_LT_GRAY);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.93, Graphics.FONT_XTINY, "DOWN: stages",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawStages(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.10, Graphics.FONT_TINY, "Stages",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var f = Graphics.FONT_XTINY;
        var y = h * 0.24;
        var dy = h * 0.10;
        line(dc, cx, y,          f, "Light", _res.pct(Staging.LIGHT).format("%.0f") + "%",
             Graphics.COLOR_GREEN);
        line(dc, cx, y + dy,     f, "Deep",  _res.pct(Staging.DEEP).format("%.0f") + "%",
             Graphics.COLOR_BLUE);
        line(dc, cx, y + dy * 2, f, "REM",   _res.pct(Staging.REM).format("%.0f") + "%",
             Graphics.COLOR_PURPLE);

        // Bar hypnogram across the lower half: one column per (downsampled) epoch.
        drawHypnogram(dc, h * 0.55, h * 0.30);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.95, Graphics.FONT_XTINY, "UP: summary",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Simple bar hypnogram: y-level encodes stage (Wake top .. Deep bottom).
    private function drawHypnogram(dc as Graphics.Dc, top as Lang.Numeric, height as Lang.Numeric) as Void {
        var stages = _res.stages;
        var n = stages.size();
        if (n == 0) { return; }
        var w = dc.getWidth();
        var x0 = w * 0.08;
        var bw = w * 0.84;
        var cols = bw.toNumber();
        if (cols > n) { cols = n; }
        if (cols < 1) { cols = 1; }
        var colW = bw / cols;

        // 4 lanes: Wake(0)=top, REM(1), Light(2), Deep(3)=bottom.
        for (var c = 0; c < cols; c++) {
            var idx = (c * n) / cols;
            if (idx >= n) { idx = n - 1; }
            var st = stages[idx];
            var lane; var col;
            if (st == Staging.WAKE)       { lane = 0; col = Graphics.COLOR_RED; }
            else if (st == Staging.REM)   { lane = 1; col = Graphics.COLOR_PURPLE; }
            else if (st == Staging.LIGHT) { lane = 2; col = Graphics.COLOR_GREEN; }
            else                          { lane = 3; col = Graphics.COLOR_BLUE; }
            var laneH = height / 4;
            var y = top + lane * laneH;
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + c * colW, y, colW + 1, laneH);
        }
    }

    private function fmtMin(m as Lang.Float) as Lang.String {
        var total = m.toNumber();
        var hh = total / 60;
        var mm = total % 60;
        return hh.format("%d") + "h" + mm.format("%02d");
    }
}
