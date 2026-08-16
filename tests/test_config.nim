import std/unittest

import std/sequtils

import niminpkg/config

suite "niminpkg/config — strict defaults":

  test "strictSwitches includes the zero-baggage memory config":
    let sw = strictSwitches()
    check sw.contains("--mm:arc")
    check sw.contains("-d:useMalloc")

  test "strictSwitches disables runtime checks and dynamic exceptions":
    let sw = strictSwitches()
    check sw.contains("--panics:on")
    check sw.contains("--exceptions:quirky")
    check sw.contains("-d:danger")

  test "strictSwitches optimizes for size":
    check strictSwitches().contains("--opt:size")

  test "strictSwitches includes aggressive C flags":
    let sw = strictSwitches()
    check sw.contains("--passc:-Os")
    check sw.contains("--passc:-flto")
    check sw.contains("--passc:-ffunction-sections")
    check sw.contains("--passc:-fdata-sections")
    check sw.contains("--passl:-Wl,--gc-sections")

  test "strictSwitches has no duplicate entries":
    let sw = strictSwitches()
    check sw.len == sw.deduplicate.len

  test "niminMarkers exposes identity defines":
    check niminMarkers().contains("nimin")