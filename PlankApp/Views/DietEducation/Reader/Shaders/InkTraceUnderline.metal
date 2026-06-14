// InkTraceUnderline — draws a warm-cream marker-pen underline beneath a
// body sentence the user long-pressed to "save". The underline traces
// left-to-right over ~600ms when first activated, then persists. After
// the trace, it stays as a static cream-marker highlight that survives
// page revisits.
//
// Mechanism: animate `progress` 0→1. A horizontal mask grows from the
// left edge to the right; alpha is modulated by a soft vertical
// Gaussian centered on the underline y so the highlight feathers
// against the body text without obscuring descenders. A faint
// per-pixel noise jitter on the alpha gives the trace a marker-on-
// paper texture (not a flat rectangle).
//
// Reduce-Motion: callers pass `progress = 1` to skip the trace —
// the underline appears at final state in one frame.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static inline float hashU(float2 p, float seed) {
    return fract(sin(dot(p + seed, float2(127.1, 311.7))) * 43758.5453);
}

[[ stitchable ]] half4 inkTraceUnderline(
    float2 position,
    half4 color,
    float progress,
    float2 size,
    float lineY,         // y position of the underline center, in points from top
    float lineThickness, // ~10pt for a marker-pen feel
    float warmHueShift   // 0...1, 0.5 = neutral cream; >0.5 warms toward apricot
) {
    // Distance from underline-center y, normalized to thickness.
    float dy = position.y - lineY;
    float vMask = exp(-(dy * dy) / (lineThickness * lineThickness * 0.5));
    if (vMask < 0.03) return color;

    // Horizontal mask grows from left edge to right; eased.
    float eased = 1.0 - (1.0 - progress) * (1.0 - progress);  // easeOut quad
    float xFront = size.x * eased;
    // Soft trailing edge so the front of the trace doesn't pop.
    float feather = 14.0;
    float hMask = clamp((xFront - position.x) / feather, 0.0, 1.0);
    if (hMask <= 0.0) return color;

    // Per-pixel marker-on-paper noise jitter — subtle.
    float n = hashU(position * 0.5, 7.0);
    float jitter = 1.0 - 0.18 * n;

    // Warm cream highlight. Tunable hue: cream (#FBF1D9) at warmHueShift 0.5,
    // apricot (#F6D9B4) at warmHueShift 1.0.
    half3 cream = half3(0.984, 0.945, 0.851);
    half3 apricot = half3(0.965, 0.851, 0.706);
    half3 hue = mix(cream, apricot, half(clamp(warmHueShift, 0.0, 1.0)));

    half alpha = half(vMask * hMask * jitter * 0.55);
    // Multiply blend on top of body text — preserves the dark cocoa
    // letters while warming the bg-row.
    half3 blended = color.rgb * (1.0 - alpha) + hue * alpha;
    return half4(blended, color.a);
}
