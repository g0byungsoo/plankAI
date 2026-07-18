#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - jkDawn
//
// App v6 — the overnight window's living light. Applied to the
// window arc's stroke (alpha-masked: untouched where the layer is
// transparent). Two behaviors in one pass:
//
//   1. A dawn wash along x: blush at the dusk end warming toward
//      rose at the dawn end, its center of gravity drifting slowly
//      so the arc reads as lit by a moving sky, not filled by a
//      static gradient.
//   2. When `live` = 1 (the kitchen is closed right now), a soft
//      luminous pulse breathes around the arc's tip — the "now"
//      point glows like the last ember of the evening.
//
// time = seconds (0 under Reduce Motion → a still, lit arc).
// Palette-locked: blush #F5D5D8 → rose #C4677A, warm-white ember.

[[ stitchable ]] half4 jkDawn(float2 position, half4 color, float2 size,
                              float time, float live, float2 tip) {
    if (color.a < 0.001h) { return color; }

    float x = position.x / max(size.x, 1.0);

    // The dawn wash — its warm center drifts ±12% around the arc.
    half3 blush = half3(0.961h, 0.835h, 0.847h);   // #F5D5D8
    half3 rose  = half3(0.769h, 0.404h, 0.478h);   // #C4677A
    float drift = 0.5 + 0.5 * sin(time * 0.35);
    float warm  = smoothstep(0.0, 1.0, clamp(x * 0.76 + drift * 0.24, 0.0, 1.0));
    half3 wash  = mix(blush, rose, half(warm));

    // Blend the wash into the stroke's own ink so cocoa stays
    // cocoa-led and rose stays rose-led — the shader is light on
    // material, never a replacement fill.
    half3 tinted = mix(color.rgb, wash, 0.5h);

    // The ember at the tip, breathing (live only).
    float d = distance(position, tip);
    float halo = exp(-(d * d) / (2.0 * 15.0 * 15.0));
    float breath = 0.55 + 0.45 * sin(time * 1.5);
    half3 ember = half3(1.0h, 0.945h, 0.93h);
    half lift = half(halo * breath * live) * 0.6h;
    half3 lit = tinted + (ember - tinted) * lift;

    return half4(lit, color.a);
}

// MARK: - jkNightSky
//
// The sleep dial's atmosphere: a whisper-quiet starfield inside the
// dial's dome. Deterministic per-pixel hash twinkle, so faint it
// reads as texture, never as decoration. Palette-safe: it only
// lifts the existing ink toward warm white by ≤4%.

[[ stitchable ]] half4 jkNightSky(float2 position, half4 color, float2 size,
                                  float time) {
    if (color.a < 0.001h) { return color; }

    float2 cell = floor(position / 3.0);
    float h = fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);

    // Keep ~2% of cells as candidate stars.
    if (h < 0.98) { return color; }

    float phase = fract(h * 91.7);
    float tw = 0.5 + 0.5 * sin(time * (0.6 + phase) + phase * 6.28318);
    half lift = half(tw) * 0.04h;
    half3 lit = color.rgb + (half3(1.0h, 0.97h, 0.95h) - color.rgb) * lift;
    return half4(lit, color.a);
}
