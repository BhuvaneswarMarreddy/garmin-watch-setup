import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Unit tests for FaceMath.mc. Build with `monkeyc --unit-test …`, run with
// `monkeydo <prg> venu3 -t`. (:test) code is left out of normal builds.

(:test)
function secFractionStaysInsideTheCurrentSecond(logger as Logger) as Boolean {
    Test.assertEqual(secFraction(1000, 1000), 0.0);
    Test.assert((secFraction(1500, 1000) - 0.5).abs() < 0.001);
    Test.assertEqual(secFraction(2600, 1000), 0.999);   // late frame: never run into the next second
    Test.assertEqual(secFraction(900, 1000), 0.0);      // never run backwards
    return true;
}

(:test)
function facetShadeLightsTheSideFacingUpperLeft(logger as Logger) as Boolean {
    Test.assert(facetShade(0.0) < 0.5);        // at 12 the clockwise facet faces away from the light
    Test.assert(facetShade(Math.PI) > 0.5);    // at 6 it faces the light
    return true;
}

(:test)
function mixColorBlendsEachChannel(logger as Logger) as Boolean {
    Test.assertEqual(mixColor(0x000000, 0xFFFFFF, 0.0), 0x000000);
    Test.assertEqual(mixColor(0x000000, 0xFFFFFF, 1.0), 0xFFFFFF);
    Test.assertEqual(mixColor(0x204060, 0x6080A0, 0.5), 0x406080);
    return true;
}
