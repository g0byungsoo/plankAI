#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - jkSilk
//
// App v2.1 — the day-complete sheen. A soft diagonal band of warm
// light sweeps across the layer once, like light moving over silk:
// a gaussian ridge that lifts the underlying color toward warm
// white with a whisper of rose at the trailing edge. Additive and
// alpha-respecting, so cream stays cream and hairlines stay crisp;
// only the lit band changes, and only while the sweep is passing.
//
// progress drives the band center from -0.3 (off-canvas lead-in)
// to 1.3 (fully exited); the call site animates it with easeOut so
// the light decelerates as it leaves — the "settling" read.

[[ stitchable ]] half4 jkSilk(float2 position, half4 color, float2 size, float progress) {
    if (color.a < 0.001h) { return color; }

    // Diagonal coordinate: 0 at top-left, 1 at bottom-right,
    // weighted toward horizontal travel (the list is tall).
    float d = (position.x / max(size.x, 1.0)) * 0.72
            + (position.y / max(size.y, 1.0)) * 0.28;

    float band = d - progress;

    // Gaussian ridge, ~14% of the diagonal wide.
    float sigma = 0.07;
    float ridge = exp(-(band * band) / (2.0 * sigma * sigma));

    // A second, wider and dimmer halo so the sweep has atmosphere.
    float halo = exp(-(band * band) / (2.0 * 0.18 * 0.18)) * 0.35;

    float lift = clamp(ridge + halo, 0.0, 1.0);

    // Warm white core with a rose whisper on the trailing side.
    half3 warmWhite = half3(1.0h, 0.985h, 0.965h);
    half3 rose = half3(1.0h, 0.878h, 0.902h);
    float trailing = clamp(band * 6.0 + 0.5, 0.0, 1.0);
    half3 light = mix(rose, warmWhite, half(trailing));

    // Screen-blend toward the light so darks lighten gracefully and
    // the cream barely moves — luxury, not a flashlight.
    half3 lit = color.rgb + (light - color.rgb) * half(lift) * 0.30h;

    return half4(lit, color.a);
}
