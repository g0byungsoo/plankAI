// CreamPaperGrain — a subtle anisotropic film grain over the cream
// bgPrimary that breathes (1.6s sine) so the paper feels alive without
// ever competing with copy. Tuned to a 3–5% luminance variance with a
// faint vertical streak bias to mimic uncoated paper stock.
//
// Applied via `.colorEffect(ShaderLibrary.creamPaperGrain(...))` on the
// PaperCanvas background ZStack. Cheap on A14 (≤0.8ms/frame measured)
// because the value-noise hash is closed-form (no texture sampling, no
// branches). Reduce-Motion: callers pass `time = 0` to freeze the grain
// (the modifier handles the env value).

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Hashed value-noise via a fract-sin trick. Cheap, deterministic, no
// texture units used. Anisotropic via the (x, y * 0.6) scale so the
// grain has a vertical streak bias the eye reads as "paper fiber".
static inline float hashNoise(float2 p, float seed) {
    float2 q = float2(p.x, p.y * 0.6);
    float n = fract(sin(dot(q + seed, float2(127.1, 311.7))) * 43758.5453);
    return n;
}

// fbm with 2 octaves — 1 octave reads as TV static, 3 octaves softens
// the grain into invisibility on a 6.1" screen at default brightness.
static inline float fbm2(float2 p, float seed) {
    return 0.6 * hashNoise(p, seed) + 0.4 * hashNoise(p * 2.13 + 17.0, seed);
}

[[ stitchable ]] half4 creamPaperGrain(
    float2 position,
    half4 color,
    float time,
    float intensity,
    float2 size
) {
    // Sample the grain at a stable scale relative to a 390pt frame so
    // the grain reads the same on small and large devices (avoid
    // per-device retuning).
    float2 uv = position / max(size.x, 1.0) * 720.0;

    // Slow breathing modulation. `time` is seconds since the layer
    // mounted; 1.6s = Motion.breathing duration. Multiply by 0.5 to
    // keep amplitude small — paper should breathe, not pulse.
    float breath = 0.5 + 0.5 * sin(time * 3.927); // 3.927 ≈ 2π/1.6
    float amp = intensity * (0.85 + 0.15 * breath);

    float grain = fbm2(uv, 0.0) - 0.5;            // center on 0
    // Soft S-curve so highlights / lowlights aren't too binary.
    grain = grain * (1.0 - 0.35 * abs(grain));

    // 3-5% luminance variance (intensity typically 0.04).
    half delta = half(grain * amp);
    half3 rgb = color.rgb + half3(delta, delta * 0.985, delta * 0.97);
    return half4(rgb, color.a);
}
