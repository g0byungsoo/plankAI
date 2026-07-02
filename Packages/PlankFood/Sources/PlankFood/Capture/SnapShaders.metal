#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - snapSweep
//
// v1.2 snap-food rebuild (2026-07-01) — the scanning light, rebuilt as
// a real Metal pass. A diagonal band of warm light travels the
// viewfinder while a whisper of animated grain sits over the whole
// frame, so the wait reads as *film developing under a lamp*, not a
// progress bar. Replaces the Canvas horizontal laser.
//
// Composition (all gaussian falloffs around the travelling band):
//   - wide dusty-rose halo    (sigma 0.16, the ambient warmth)
//   - warm cream inner glow   (sigma 0.045, the lamp)
//   - crisp warm-white core   (sigma 0.008, the light edge itself)
//   - sparkle grain across the frame (additive-only, ±0 floor)
//
// The view mounts this over the photo/preview with .plusLighter, so
// the shader returns premultiplied ADDITIVE light: rgb carries the
// energy, alpha stays 0 (nothing is occluded, light is only added).
// `gate` = sin(phase·π) fades the band in at the top of each cycle
// and out at the bottom — no loop-boundary teleport.
//
// Closed-form, no texture sampling, no branches on the hot path:
// comfortably under the 0.8 ms/frame budget the app's other shaders
// hold on A14-class GPUs.

[[ stitchable ]] half4 snapSweep(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float active
) {
    float2 safeSize = max(size, float2(1.0, 1.0));
    float2 uv = position / safeSize;

    // Diagonal travel axis — light reads top-left → bottom-right,
    // the direction a hand would sweep a lamp across a table.
    float2 dir = normalize(float2(0.30, 0.954));
    float d = dot(uv, dir);

    float cycle = 2.6;
    float phase = fract(time / cycle);
    float eased = phase * phase * (3.0 - 2.0 * phase);
    float center = mix(-0.20, 1.44, eased);
    float gate = sin(phase * 3.14159265) * active;

    float delta = d - center;
    float halo = exp(-(delta * delta) / (2.0 * 0.16 * 0.16));
    float glow = exp(-(delta * delta) / (2.0 * 0.045 * 0.045));
    float core = exp(-(delta * delta) / (2.0 * 0.008 * 0.008));

    half3 rose  = half3(0.77h, 0.40h, 0.48h);
    half3 cream = half3(1.00h, 0.96h, 0.93h);
    half3 white = half3(1.00h, 0.99h, 0.97h);

    half3 light = rose  * half(halo * 0.14)
                + cream * half(glow * 0.28)
                + white * half(core * 0.80);

    // Sparkle grain — additive-only (plusLighter can't darken), so
    // it's a faint field of living light rather than noise dirt.
    float n = fract(sin(dot(position + float2(time * 61.7, time * 39.3),
                            float2(12.9898, 78.233))) * 43758.5453);
    half sparkle = half(max(n - 0.86, 0.0) * 0.10);

    half3 rgb = (light + sparkle) * half(gate);
    return half4(rgb.r, rgb.g, rgb.b, 0.0h);
}
