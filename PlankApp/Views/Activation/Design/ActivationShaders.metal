// ActivationShaders — the premium "alive surface" for the activation
// screens. One stitchable colorEffect, `activationGrainfield`, layered
// on the cream bgPrimary so the flat fill reads as paper + soft light
// depth instead of an iOS background.
//
// Two ingredients, both ultra-subtle by design:
//   1. A faint radial light bloom, biased toward the upper-center of
//      the frame (light falling onto a page from above). Warm cream,
//      gaussian falloff, ≈2-4% lift at the core.
//   2. A breathing closed-form film grain (no texture sampling, no
//      branches) at ≈2.5% luminance variance with a faint vertical
//      fiber bias, so the paper feels alive without ever competing
//      with copy.
//
// Driven by a single `time` uniform (seconds) fed from a
// `TimelineView(.animation)` in GrainfieldBackground. Reduce-Motion:
// the SwiftUI wrapper freezes `time = 0`, which yields a static bloom
// + static grain (still rendered, just not animated).
//
// Modeled on the project's existing closed-form approach in
// CreamPaperGrain.metal — measured ≤0.8ms/frame on A14. NO red is
// ever introduced: the bloom tint is a warm cream where R ≈ G ≥ B.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Hashed value-noise via a fract-sin trick. Cheap, deterministic, no
// texture units used. Anisotropic via the (x, y * 0.6) scale so the
// grain carries a vertical fiber bias the eye reads as "paper".
static inline float agf_hashNoise(float2 p, float seed) {
    float2 q = float2(p.x, p.y * 0.6);
    float n = fract(sin(dot(q + seed, float2(127.1, 311.7))) * 43758.5453);
    return n;
}

// 2-octave fbm. 1 octave reads as TV static; 3 octaves softens the
// grain into invisibility on a 6.1" screen at default brightness.
static inline float agf_fbm2(float2 p, float seed) {
    return 0.6 * agf_hashNoise(p, seed) + 0.4 * agf_hashNoise(p * 2.13 + 17.0, seed);
}

// Soft gaussian light pool centered at `c` (normalized 0..1). Larger
// `spread` = tighter pool.
static inline float agf_pool(float2 uv, float2 c, float spread) {
    float2 d = uv - c;
    return exp(-dot(d, d) * spread);
}

[[ stitchable ]] half4 activationGrainfield(
    float2 position,
    half4 color,
    float time,
    float intensity,
    float2 size
) {
    half3 base = color.rgb;

    // ── Radial light bloom ───────────────────────────────────────────
    // Normalized coords, then a single warm pool biased upper-center.
    // The center drifts a hair (≈1% of the frame) on a glacial sine so
    // the light "settles" rather than sitting dead-still; the drift is
    // imperceptible as motion but kills the printed-poster flatness.
    float2 nuv = position / max(size, float2(1.0, 1.0));
    float t = time * 0.05;
    float2 bloomCenter = float2(0.50 + 0.012 * sin(t * 0.7),
                                0.34 + 0.010 * cos(t * 0.5));
    float bloom = agf_pool(nuv, bloomCenter, 1.6);

    // Warm cream highlight — R == G, B slightly lower, so the lift is a
    // touch golden and NEVER strays cool or pink. Capped tiny.
    half3 warm = half3(1.0h, 0.992h, 0.965h);
    half bloomK = half(bloom) * half(intensity) * 0.9h;
    half3 col = mix(base, warm, bloomK);

    // A whisper of vignette at the extreme corners so the page edge
    // reads as paper falling into shade, not a hard crop. Very small.
    float corner = agf_pool(nuv, float2(0.5, 0.5), 0.9);
    col = mix(col * 0.992h, col, half(corner));

    // ── Breathing film grain ─────────────────────────────────────────
    // Sample at a stable scale relative to the frame width so the grain
    // reads identically across device sizes.
    float2 guv = position / max(size.x, 1.0) * 720.0;
    float breath = 0.5 + 0.5 * sin(time * 3.927);   // 1.6s period
    float gamp = intensity * 0.62 * (0.85 + 0.15 * breath);
    float grain = agf_fbm2(guv, 0.0) - 0.5;
    grain = grain * (1.0 - 0.35 * abs(grain));       // soft S-curve
    half gd = half(grain * gamp);
    col += half3(gd, gd * 0.99h, gd * 0.975h);

    return half4(col, color.a);
}
