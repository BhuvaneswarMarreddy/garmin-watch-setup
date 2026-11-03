import Toybox.Lang;
import Toybox.Math;

// How far (0..0.999) the sweep is through the current second. ClockTime only has
// whole seconds, so the view stamps System.getTimer() when the second changes and
// measures from there. Clamped so a late frame never runs into the next second
// (which would make the hand snap back) and never runs backwards.
function secFraction(nowMs as Number, secStartMs as Number) as Float {
    var f = (nowMs - secStartMs) / 1000.0;
    if (f < 0.0)   { return 0.0; }
    if (f > 0.999) { return 0.999; }
    return f;
}

// 0..1: how much a hand's clockwise facet faces the light, which falls from the
// upper left. The other facet gets 1 - this, so the bright side swaps as the hand turns.
function facetShade(angle as Float) as Float {
    return (0.5 - 0.42 * 0.7071 * (Math.cos(angle) + Math.sin(angle))).toFloat();
}

// Blend two 0xRRGGBB colours: k = 0 gives dark, k = 1 gives light.
function mixColor(dark as Number, light as Number, k as Float) as Number {
    var out = 0;
    for (var shift = 16; shift >= 0; shift -= 8) {
        var d = (dark >> shift) & 0xFF;
        var l = (light >> shift) & 0xFF;
        out |= (d + (l - d) * k + 0.5).toNumber() << shift;
    }
    return out;
}
