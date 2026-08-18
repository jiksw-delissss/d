/*
================================================================================
  World-Space RSM Global Illumination — Super Duper Vanilla
  
  Technique: Reflective Shadow Map (RSM) Virtual Point Lights
  
  Verified SDV shadow buffer layout (from shadow_solid.glsl / shadow_block.glsl):
    shadowcolor0  — tinted shadow colour (mostly vec3(0) for opaque terrain)
    shadowcolor1  — surface albedo RGB  (block colour, written as shdAlbedo.rgb)
    shadowtex0/1  — sampler2DShadow depth comparison — NEVER read here

  Shadow distortion (from shadow vertex shader):
    gl_Position.xyz = vec3(xy / (length(xy) + 0.1), z * 0.2)
    i.e. distorted_xy = raw_xy / (length(raw_xy) + 0.1)
    
  Stability: noise rotation uses a world-space integer hash so the GI
  pattern is pinned to world geometry, not the screen.
================================================================================
*/

#ifndef WORLD_GI_GLSL
#define WORLD_GI_GLSL

// shadowMapResolution is defined in shdMapping.glsl (only when SHADOW_MAPPING is on).
// Provide a fallback so worldGI compiles even without shadow mapping enabled.
#ifndef shadowMapResolution
    #define shadowMapResolution 1024
#endif

// ── Tunables ──────────────────────────────────────────────────────────────────
#ifndef WGI_SAMPLES
  #define WGI_SAMPLES 8
#endif
#ifndef WGI_RADIUS
  #define WGI_RADIUS 0.15
#endif
#ifndef WGI_STRENGTH
  #define WGI_STRENGTH 1.2
#endif
#ifndef WGI_MAX_DIST
  #define WGI_MAX_DIST 20.0
#endif

// ── World-space hash → stable [0,1) rotation per surface point ───────────────
// Quantised to 0.5-block grid. Pure arithmetic, no texture lookup.
float wgi_worldHash(vec3 feetPos) {
    ivec3 ip = ivec3(floor(feetPos * 2.0));
    uint h = uint(ip.x * 1664525 + ip.y * 22695477 + ip.z * 1013904223);
    h ^= h >> 16u;  h *= 0x45d9f3bu;
    h ^= h >> 16u;  h *= 0x45d9f3bu;
    h ^= h >> 16u;
    return float(h & 0xFFFFFFu) / 16777216.0;
}

// ── R2 low-discrepancy disk sample ────────────────────────────────────────────
vec2 wgi_r2Disk(int i, float rot) {
    float u = fract(float(i) * 0.7548776662 + rot);
    float v = fract(float(i) * 0.5698402909 + rot * 0.618033989);
    float r = sqrt(u);
    float a = v * 6.28318530718;
    return vec2(r * cos(a), r * sin(a));
}

// ── World (feet-player) → shadow UV [0,1] ────────────────────────────────────
// Matches the vertex shader distortion: xy / (length(xy) + 0.1) + 0.5
// Returns vec2(-1) when outside frustum.
vec2 wgi_toShadowUV(vec3 feetPos) {
    vec3 lv = mat3(shadowModelView) * feetPos + shadowModelView[3].xyz;
    // Shadow z is stored as lv.z * 0.2 — we only need xy for UV
    float len = length(lv.xy);
    vec2 uv = lv.xy / (len + 0.1) + 0.5;
    if (any(lessThan(uv, vec2(0.001))) || any(greaterThan(uv, vec2(0.999))))
        return vec2(-1.0);
    return uv;
}

// ── Inverse distortion: shadow UV → light-view XY ────────────────────────────
// Inverse of: d = r / (r + 0.1)  →  r = 0.1*d / (1 - d)
vec2 wgi_fromShadowUV(vec2 uv) {
    vec2 d = uv - 0.5;
    float dm = length(d);
    if (dm < 0.001) return vec2(0.0);
    float r = 0.1 * dm / max(1.0 - dm, 1e-6);
    return d * (r / dm);
}

// ── Sample one VPL and return its radiance contribution ──────────────────────
vec3 wgi_sampleVPL(
    vec3  rcvFeetPos,       // receiver world position
    vec3  rcvNormal,        // receiver world-space normal
    vec2  rsmUV,            // RSM texel UV to sample
    float rcvLightZ,        // receiver Z in light-view space (for emitter pos approx)
    vec3  sunDir            // sun direction in world space (toward sun)
) {
    ivec2 tx = ivec2(rsmUV * float(shadowMapResolution));

    // Emitter albedo from shadowcolor1 (plain sampler2D, RGB only)
    vec3 emitAlbedo = texelFetch(shadowcolor1, tx, 0).rgb;
    if (dot(emitAlbedo, vec3(0.299, 0.587, 0.114)) < 0.02) return vec3(0.0);

    // Reconstruct emitter world position:
    //  - invert shadow UV distortion → light-view XY
    //  - use receiver's light-view Z (co-planar approximation within WGI_RADIUS)
    //  - rotate back via transpose(mat3(shadowModelView))
    vec2 emXY   = wgi_fromShadowUV(rsmUV);
    vec3 emLV   = vec3(emXY, rcvLightZ);
    vec3 emFeet = transpose(mat3(shadowModelView)) * (emLV - shadowModelView[3].xyz);
    // Nudge emitter off the surface along sun direction to avoid self-hit
    emFeet += sunDir * 0.6;

    vec3  diff  = rcvFeetPos - emFeet;
    float dist2 = dot(diff, diff);
    float dist  = sqrt(dist2) + 0.001;
    if (dist > WGI_MAX_DIST) return vec3(0.0);

    float atten   = 1.0 / max(dist2, 0.5);
    vec3  dir     = diff / dist;

    // Emitter faces sun — use NdotL with sun direction
    float cosEmit = max(0.0, dot(sunDir, -dir));
    float cosRcv  = max(0.0, dot(rcvNormal, dir));
    float ff      = cosEmit * cosRcv * atten;
    if (ff < 0.0001) return vec3(0.0);

    #ifdef WORLD_LIGHT
        return emitAlbedo * lightCol * ff;
    #else
        return emitAlbedo * ff;
    #endif
}

// ── Main entry — compute world-space RSM GI ───────────────────────────────────
vec3 computeWorldGI(
    vec3  feetPos,       // feetPlayerPos = eyePlayerPos + gbufferModelViewInverse[3].xyz
    vec3  worldNormal,   // surface normal in world space
    vec3  albedo,        // surface albedo (for colour bleed)
    float skylight,      // eye skylight 0..1
    float frameFrac      // TAA frame fraction (0 if TAA disabled)
) {
    vec2 rcvUV = wgi_toShadowUV(feetPos);
    if (rcvUV.x < 0.0) return albedo * skylight * AMBIENT_LIGHTING;

    // Receiver Z in light-view space (reused for all emitter approximations)
    float rcvLightZ = (mat3(shadowModelView) * feetPos + shadowModelView[3].xyz).z;

    // Sun direction: +Z column of shadowModelView rotated to world space
    vec3 sunDir = normalize(vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z));

    // World-space stable rotation + small TAA jitter
    float rot = fract(wgi_worldHash(feetPos) + frameFrac * 0.618033989);

    vec3 gi = vec3(0.0);
    for (int i = 0; i < WGI_SAMPLES; ++i) {
        vec2 uv = rcvUV + wgi_r2Disk(i, rot) * WGI_RADIUS;
        if (any(lessThan(uv, vec2(0.001))) || any(greaterThan(uv, vec2(0.999)))) continue;
        gi += wgi_sampleVPL(feetPos, worldNormal, uv, rcvLightZ, sunDir);
    }

    gi = (gi / float(WGI_SAMPLES)) * albedo * WGI_STRENGTH;
    return min(gi, vec3(2.0));
}

// ── Lightweight depth+normal bilateral denoise (8-tap Poisson) ───────────────
vec3 wgi_denoise(vec3 gi, vec2 uv, float depth, vec3 normal) {
    const vec2 P[8] = vec2[8](
        vec2(-0.94,-0.40), vec2( 0.94,-0.77),
        vec2(-0.09,-0.93), vec2( 0.34, 0.29),
        vec2(-0.92, 0.46), vec2(-0.81,-0.88),
        vec2(-0.38, 0.28), vec2( 0.97, 0.75)
    );
    vec3  sum = gi;
    float tot = 1.0;
    vec2  px  = vec2(pixelWidth, pixelHeight) * 2.0;
    for (int i = 0; i < 8; ++i) {
        vec2  s  = uv + P[i] * px;
        if (s.x < 0.0 || s.x > 1.0 || s.y < 0.0 || s.y > 1.0) continue;
        float sd = texture(depthtex0, s).x;
        if (sd > 0.9999) continue;
        float dw = exp(-abs(sd - depth) * 120.0);
        if (dw < 0.02) continue;
        float nw = pow(max(0.0, dot(normalize(texture(colortex1, s).xyz), normal)), 4.0);
        float w  = dw * nw;
        sum += texture(colortex4, s).rgb * w;
        tot += w;
    }
    return sum / tot;
}

#endif // WORLD_GI_GLSL
