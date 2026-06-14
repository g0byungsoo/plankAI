// InkBleedReveal — italic punch words bleed-in like ink on paper over
// ~300ms when a page mounts. Applied as a per-word `.colorEffect` on a
// Text laid out by InkRevealHeadline; the call site passes the word's
// origin in screen space + a per-word seed so adjacent reveals don't
// align.
//
// Mechanism: animate `progress` 0→1. A jagged radial mask centered at
// `origin` grows from 0 to 1.1× the word's max extent, with fbm-warped
// edges so the bleed feels like ink wicking across uncoated paper —
// not a clean wipe. Pixels outside the mask render transparent;
// pixels inside take the base color. Pixels in the feather band (≈8px)
// take a slightly darker color tinted toward cocoa so the punch word
// reads as "ink fresh, still wet" for a beat after landing.
//
// Reduce-Motion: callers pass `progress = 1` to skip the animation —
// the shader still applies but the mask is fully open, so the
// rendering is identical to a normal Text.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static inline float hash21(float2 p, float seed) {
    return fract(sin(dot(p + seed, float2(127.1, 311.7))) * 43758.5453);
}

static inline float valueNoise(float2 p, float seed) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i, seed);
    float b = hash21(i + float2(1.0, 0.0), seed);
    float c = hash21(i + float2(0.0, 1.0), seed);
    float d = hash21(i + float2(1.0, 1.0), seed);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

[[ stitchable ]] half4 inkBleedReveal(
    float2 position,
    half4 color,
    float progress,
    float2 origin,
    float2 size,
    float seed
) {
    if (color.a == 0.0h) { return color; }

    // Distance from origin in normalized space. We treat the word's
    // half-extent as `size.x * 0.5` — the call site passes the per-
    // word width via the size param.
    float2 toCenter = position - origin;
    float dist = length(toCenter);

    // Radius grows non-linearly so the front of the bleed accelerates
    // then settles. eased = 1 - (1-progress)^2 (easeOut quad).
    float eased = 1.0 - (1.0 - progress) * (1.0 - progress);
    float maxR = max(size.x, size.y) * 0.65;
    float radius = maxR * (eased * 1.1);

    // Warp the radius with low-freq noise so the bleed front is
    // jagged like real ink. Amplitude shrinks as progress→1 so the
    // settled state is clean.
    float warpAmp = (1.0 - eased) * 10.0 + 2.0;
    float n = valueNoise(position * 0.06 + seed, seed) - 0.5;
    float warpedDist = dist - n * warpAmp;

    // Feather band (~6px) for the wet-ink edge.
    float feather = 6.0;
    float mask = clamp((radius - warpedDist) / feather, 0.0, 1.0);

    if (mask <= 0.0) {
        return half4(0.0, 0.0, 0.0, 0.0);
    }

    // Darken inside the feather band slightly so the leading edge
    // reads as "fresh ink, still wet."
    half edgeDarken = half(0.92 + 0.08 * mask);
    half3 rgb = color.rgb * edgeDarken;
    return half4(rgb, color.a * half(mask));
}
