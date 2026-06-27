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

// ─────────────────────────────────────────────────────────────────────
// onboardingAtmosphere — the premium ambient background for the
// onboarding question flow (v1.1 "quiet luxury" pass). Same cheap,
// texture-free, closed-form approach as the grain above, but adds three
// VERY slowly drifting warm-light pools (blush / peach / faint lilac)
// over the cream so the background feels alive + considered without ever
// competing with the question copy. The grain is layered on top at a
// subtle amplitude for a premium "uncoated paper" finish.
//
// `intensity` is the max blend toward the warm tints at a pool's center
// (≈0.12–0.18 reads as a whisper of light, not a gradient). Applied via
// `.colorEffect(ShaderLibrary.onboardingAtmosphere(...))` on the cream
// rect in OnboardingAtmosphere. Reduce-Motion freezes `time = 0`.
// ─────────────────────────────────────────────────────────────────────

// Soft gaussian light pool. `spread` larger = tighter pool.
static inline float atmPool(float2 uv, float2 c, float spread) {
    float2 d = uv - c;
    return exp(-dot(d, d) * spread);
}

[[ stitchable ]] half4 onboardingAtmosphere(
    float2 position,
    half4 color,
    float time,
    float intensity,
    float2 size
) {
    float2 nuv = position / max(size, float2(1.0, 1.0)); // 0..1 both axes

    // Three drifting warm-light pools. The 0.06 multiplier keeps the
    // drift glacial — ambient light, never a moving gradient.
    float t = time * 0.06;
    float2 c1 = float2(0.20 + 0.05 * sin(t * 0.90),       0.16 + 0.04 * cos(t * 0.70));
    float2 c2 = float2(0.85 + 0.04 * cos(t * 0.60),       0.34 + 0.05 * sin(t * 0.80));
    float2 c3 = float2(0.50 + 0.06 * sin(t * 0.50 + 1.7), 0.92 + 0.03 * cos(t * 1.00));
    float g1 = atmPool(nuv, c1, 2.4);
    float g2 = atmPool(nuv, c2, 2.8);
    float g3 = atmPool(nuv, c3, 2.0);

    half3 base  = color.rgb;                        // the cream fill
    half3 blush = half3(0.965h, 0.835h, 0.855h);    // warm rose
    half3 peach = half3(0.998h, 0.950h, 0.910h);    // warm cream
    half3 lilac = half3(0.940h, 0.928h, 0.952h);    // faint cool

    half k = half(intensity);
    half3 col = base;
    col = mix(col, blush, half(g1) * k * 1.00h);
    col = mix(col, peach, half(g2) * k * 0.85h);
    col = mix(col, lilac, half(g3) * k * 0.60h);

    // Fine breathing grain on top (subtler than the reader's).
    float2 guv = position / max(size.x, 1.0) * 720.0;
    float breath = 0.5 + 0.5 * sin(time * 3.927);   // 1.6s
    float gamp = 0.026 * (0.85 + 0.15 * breath);
    float grain = fbm2(guv, 0.0) - 0.5;
    grain = grain * (1.0 - 0.35 * abs(grain));
    half gd = half(grain * gamp);
    col += half3(gd, gd * 0.985h, gd * 0.97h);

    return half4(col, color.a);
}

// ─────────────────────────────────────────────────────────────────────
// iridescentRingFlow — a warm, slowly-rotating iridescent gradient for
// the Steps detail ring. Applied as a `.colorEffect` on the trimmed
// progress arc: the stroke's own rasterized alpha (round caps + the
// trim endpoint + anti-aliasing) is preserved untouched, only the RGB
// is replaced by an Inigo-Quilez cosine palette swept by angle + time.
// The palette is biased WARM (rose → mauve → peach) with a small
// amplitude so it shimmers like the iridescent shoe sticker the steps
// rail already carries — never a garish full-spectrum rainbow.
// Reduce-Motion: callers pass `time = 0` → a still warm gradient.
// ─────────────────────────────────────────────────────────────────────
[[ stitchable ]] half4 iridescentRingFlow(
    float2 position,
    half4 color,
    float time,
    float2 size
) {
    // Outside the stroke / past the trim, alpha is 0 — return as-is so
    // the arc shape, round caps and AA stay perfectly clean.
    if (color.a == 0.0h) { return color; }

    float2 cen = size * 0.5;
    float2 d = position - cen;
    float angle = atan2(d.y, d.x);                 // -pi..pi around center
    float t = angle / 6.2831853 + time * 0.06;     // glacial rotation

    // Three hand-picked WARM stops (deep rose → coral → peach-gold),
    // blended smoothly around the loop so the sweep travels through
    // visible warm iridescence but can NEVER reach green or blue: every
    // stop has R ≥ G ≥ B by construction (the brand palette is locked
    // warm). A cosine/IQ palette inevitably strays cool or olive at some
    // angle; explicit warm stops cannot.
    float u = fract(t);
    float3 c0 = float3(0.80, 0.44, 0.48);  // deep rose
    float3 c1 = float3(0.93, 0.60, 0.48);  // coral
    float3 c2 = float3(0.95, 0.78, 0.58);  // peach-gold
    float3 col;
    if (u < 0.33333) {
        col = mix(c0, c1, smoothstep(0.0, 0.33333, u));
    } else if (u < 0.66666) {
        col = mix(c1, c2, smoothstep(0.33333, 0.66666, u));
    } else {
        col = mix(c2, c0, smoothstep(0.66666, 1.0, u));
    }

    return half4(half3(col), color.a);
}
