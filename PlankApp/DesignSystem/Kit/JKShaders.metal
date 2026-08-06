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

// MARK: - jeniAtmosphere (v11.5 — the light behind the day)
//
// Both references the founder set (MyFitnessPal, Lovi) open on a
// coloured ATMOSPHERE rather than a flat field: a soft luminous
// wash behind the header that gives the page depth before a single
// element is read. Jeni's version is warm paper light, not a
// gradient sticker — two slow bloom centres drifting against each
// other so the surface never sits perfectly still, plus a whisper
// of rose where they overlap.
//
// It runs ONLY over the header band and lifts toward warm white;
// the paper stays paper (#FCFAF7) and ink stays ink. `t` is a
// seconds-scale phase from the call site; `intensity` fades the
// whole effect for Reduce Motion / low-power.

[[ stitchable ]] half4 jeniAtmosphere(float2 position, half4 color, float2 size,
                                      float t, float intensity) {
    if (color.a < 0.001h) { return color; }
    if (intensity < 0.001) { return color; }

    float2 uv = position / max(size, float2(1.0));

    // Two blooms on slow, mutually-prime orbits: their beat period is
    // long enough that a returning user never sees the loop.
    float2 c1 = float2(0.28 + 0.10 * sin(t * 0.21),
                       0.16 + 0.06 * cos(t * 0.17));
    float2 c2 = float2(0.78 + 0.09 * cos(t * 0.13),
                       0.30 + 0.07 * sin(t * 0.11));

    // Aspect-corrected distance so the blooms stay round on a tall band.
    float aspect = max(size.x, 1.0) / max(size.y, 1.0);
    float2 d1 = float2((uv.x - c1.x) * aspect, uv.y - c1.y);
    float2 d2 = float2((uv.x - c2.x) * aspect, uv.y - c2.y);

    float b1 = exp(-dot(d1, d1) / (2.0 * 0.34 * 0.34));
    float b2 = exp(-dot(d2, d2) / (2.0 * 0.30 * 0.30));

    // The band fades out downward: the atmosphere belongs to the top
    // of the page and must never fight the content below it.
    float fall = smoothstep(1.0, 0.12, uv.y);

    float warm = (b1 * 0.62 + b2 * 0.48) * fall * intensity;
    // Where the blooms overlap, the faintest rose blush.
    float blush = b1 * b2 * fall * intensity;

    // Lift toward warm white; rose only in the overlap. Values are
    // deliberately small — this must read as LIGHT, never as colour.
    half3 warmLight = half3(1.0h, 0.985h, 0.965h);
    half3 roseLight = half3(1.0h, 0.938h, 0.945h);

    // Tuned on device captures: at 0.07 the light was invisible on
    // cream and the band read as flat paper. These values are the
    // point where depth appears and colour still does not.
    half3 lit = mix(color.rgb, warmLight, half(clamp(warm * 0.34, 0.0, 0.30)));
    lit = mix(lit, roseLight, half(clamp(blush * 0.30, 0.0, 0.20)));

    return half4(lit, color.a);
}
