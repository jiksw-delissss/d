/*
================================ /// Super Duper Vanilla - Procedural Grass /// ================================

    Procedural billboard grass blades rendered on top of grass_block terrain.
    Adapted from the ShaderToy raytraced grass field approach.

    Strategy:
      - Called per-fragment from gbuffers_terrain on upward-facing grass_block
        top faces (blockId == 13200, TBN[2].y > 0.85).
      - For each fragment we build a local tile grid in world-XZ, generate
        camera-facing billboard triangles (base + tip) for blades around
        the surface point, and Möller–Trumbore intersect the view ray.
      - Wind uses WIND_SPEED / WIND_FREQUENCY from settings.glsl to stay
        in sync with vanilla foliage sway.
      - Biome tint is passed in as a vec3 (caller passes vertexColor).

    All parameters are function arguments — no extra uniforms needed beyond
    what gbuffers_terrain already has.

================================ /// Super Duper Vanilla - Procedural Grass /// ================================
*/

// ─────────────────────────────────────────────────────────────────────────────
// Tunables  (can be overridden by settings.glsl before this file is included)
// ─────────────────────────────────────────────────────────────────────────────

#ifndef GRASS_BLADE_HEIGHT
    #define GRASS_BLADE_HEIGHT    0.72   // max blade height in world-units
#endif
#ifndef GRASS_BLADE_HALFWIDTH
    #define GRASS_BLADE_HALFWIDTH 0.10   // half-width of the billboard quad
#endif
#ifndef GRASS_WIND_SWAY
    #define GRASS_WIND_SWAY       0.22   // maximum tip XZ displacement from wind
#endif
#ifndef GRASS_SEARCH_RADIUS
    #define GRASS_SEARCH_RADIUS   2      // tile half-extent to search (tiles)
#endif
#ifndef GRASS_FADE_START
    #define GRASS_FADE_START      8.0    // distance (blocks) where blades begin fading
#endif
#ifndef GRASS_FADE_END
    #define GRASS_FADE_END        20.0   // distance (blocks) where blades fully vanish
#endif

// ─────────────────────────────────────────────────────────────────────────────
// Internal hash helpers
// ─────────────────────────────────────────────────────────────────────────────

float _gHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 _gHash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)),
                          dot(p, vec2(269.5, 183.3)))) * 43758.5453123);
}

// ─────────────────────────────────────────────────────────────────────────────
// Wind:  layered sine, matched to waveTerrain.glsl phase/amplitude convention
// Returns XZ displacement for the blade tip.
// ─────────────────────────────────────────────────────────────────────────────
vec2 _gWindOffset(vec2 worldXZ, float t) {
    float phase = t * 4.0 * WIND_SPEED;
    float freq  = WIND_FREQUENCY * 0.5;

    float w1 = sin(-worldXZ.x * freq * 0.50 + phase * 0.80 - worldXZ.y * 0.02) * 0.60;
    float w2 = sin(-worldXZ.y * freq * 0.80 + phase * 1.20 + worldXZ.x * 0.01) * 0.30;
    float w3 = sin(-(worldXZ.x + worldXZ.y) * freq * 1.30 + phase * 1.50)      * 0.10;

    float sway = (w1 + w2 + w3) * GRASS_WIND_SWAY;
    return vec2(sway * 0.85, sway * 0.35);
}

// ─────────────────────────────────────────────────────────────────────────────
// Möller–Trumbore ray–triangle test  (returns t > 0 on hit, else -1.0)
// bary.x = u barycentric, bary.y = v barycentric
// ─────────────────────────────────────────────────────────────────────────────
float _gRayTri(vec3 ro, vec3 rd,
               vec3 v0, vec3 v1, vec3 v2,
               out vec2 bary) {
    const float EPS = 1e-6;
    vec3  e1  = v1 - v0;
    vec3  e2  = v2 - v0;
    vec3  h   = cross(rd, e2);
    float a   = dot(e1, h);
    if (abs(a) < EPS) return -1.0;
    float  f  = 1.0 / a;
    vec3   s  = ro - v0;
    float  u  = f * dot(s, h);
    if (u < 0.0 || u > 1.0) return -1.0;
    vec3   q  = cross(s, e1);
    float  v  = f * dot(rd, q);
    if (v < 0.0 || u + v > 1.0) return -1.0;
    float  t  = f * dot(e2, q);
    if (t < EPS) return -1.0;
    bary = vec2(u, v);
    return t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main entry point
//
//   worldPos   – world-space XYZ of the grass_block top surface under this pixel
//   eyePos     – camera world-space position (cameraPosition uniform)
//   eyeDir     – normalised world-space view ray (worldPos - eyePos, normalised)
//   skyLight   – sky lightmap at this surface (lmCoord.y)
//   biomeCol   – biome grass tint (vertexColor from terrain vertex)
//   grassBlockCoord – flat-shaded integer block coordinate (no interpolation)
//   t          – current time (globalTime)
//
// Returns: rgb = grass colour (linear), a = coverage blend weight [0,1]
// ─────────────────────────────────────────────────────────────────────────────
vec4 sampleProceduralGrass(
        vec3  worldPos,
        vec3  eyePos,
        vec3  eyeDir,
        float skyLight,
        vec3  biomeCol,
        ivec2 grassBlockCoord,
        float t)
{
    // Distance-based fade — bail early if too far
    float dist     = length(worldPos - eyePos);
    float distFade = 1.0 - smoothstep(GRASS_FADE_START, GRASS_FADE_END, dist);
    if (distFade <= 0.001) return vec4(0.0);

    // Terrain hit distance along the view ray — used to ensure blades
    // are only accepted when they are in front of the terrain surface.
    float terrainT = dist;

    // Ground Y: top face of the block the ray hit
    float groundY  = floor(worldPos.y + 0.5) + 0.5;

    // Use the flat-shaded block coordinate passed from the vertex shader.
    // This ensures all fragments on the same block use the SAME integer grid,
    // with no interpolation-based drift between fragments.
    vec2  blockCellFloat = vec2(grassBlockCoord);

    // Ray origin / direction (world space)
    vec3 ro = eyePos;
    vec3 rd = eyeDir;

    float closestT = 1e20;
    vec4  hitColor = vec4(0.0);
    bool  anyHit   = false;

    int R = GRASS_SEARCH_RADIUS;

    for (int ix = -R; ix <= R; ix++) {
        for (int iz = -R; iz <= R; iz++) {

            // One blade per block cell, deterministically placed
            // Use the stable integer block coordinate for all fragments on this face.
            vec2  cell     = blockCellFloat + vec2(float(ix), float(iz));
            vec2  jitter   = _gHash2(cell);
            vec2  bladeXZ  = cell + 0.15 + jitter * 0.70;

            // Wind tip offset
            vec2  wind     = _gWindOffset(bladeXZ, t);

            // Height variation per blade
            float hVar     = _gHash(cell * 3.7) * 0.35 + 0.65;
            float bladeH   = GRASS_BLADE_HEIGHT * hVar;

            // Use a deterministic blade direction based on position (not camera).
            // This keeps the blade orientation fixed in world space.
            float bladeAngle = _gHash(cell * 2.1) * 6.283185307;
            vec2  bladeDir   = vec2(cos(bladeAngle), sin(bladeAngle));
            vec2  bladePerpendicular = vec2(-bladeDir.y, bladeDir.x);
            
            vec3  bladeRight = normalize(vec3(bladeDir.x, 0.0, bladeDir.y));
            vec3  bladeLeft  = normalize(vec3(bladePerpendicular.x, 0.0, bladePerpendicular.y));
            vec3  bladeUp    = vec3(0.0, 1.0, 0.0);

            // World-space billboard vertices
            //   v0 = base left,  v1 = base right,  v2 = animated tip
            vec3  base     = vec3(bladeXZ.x, groundY, bladeXZ.y);
            vec3  v0       = base + bladeRight * (-GRASS_BLADE_HALFWIDTH) + bladeUp * 0.05;
            vec3  v1       = base + bladeRight * ( GRASS_BLADE_HALFWIDTH) + bladeUp * 0.05;
            vec3  v2       = base + vec3(wind.x, bladeH, wind.y) + bladeUp * 0.05;

            // Second blade face (perpendicular cross)
            vec3  v3       = base + bladeLeft * (-GRASS_BLADE_HALFWIDTH) + bladeUp * 0.05;
            vec3  v4       = base + bladeLeft * ( GRASS_BLADE_HALFWIDTH) + bladeUp * 0.05;

            // ── Test both blade faces ────────────────────────────────────────
            // Try first blade
            vec2  bary;
            float tHit = _gRayTri(ro, rd, v0, v1, v2, bary);
            
            // Try second blade (perpendicular cross)
            vec2  bary2;
            float tHit2 = _gRayTri(ro, rd, v3, v4, v2, bary2);
            
            // Use whichever blade is closer
            if (tHit2 >= 0.0 && (tHit < 0.0 || tHit2 < tHit)) {
                tHit = tHit2;
                bary = bary2;
            }
            
            if (tHit < 0.0 || tHit >= closestT) continue;

            // If the blade intersection is further than the terrain surface
            // under this fragment, it is occluded and should be ignored.
            if (tHit > terrainT + 0.001) continue;

            // Reject hits outside the blade's vertical extent
            vec3  hitPt = ro + rd * tHit;
            if (hitPt.y < groundY - 0.05 || hitPt.y > groundY + bladeH + 0.05) continue;

            // ── Blade colour ─────────────────────────────────────────────────
            // Height parameter along the blade [0=root .. 1=tip]
            float hT      = clamp((hitPt.y - groundY) / max(bladeH, 0.001), 0.0, 1.0);

            // Root: darker, more saturated green.  Tip: lighter, slightly golden.
            vec3  rootCol  = biomeCol * vec3(0.50, 0.78, 0.42);
            vec3  tipCol   = biomeCol * vec3(0.88, 1.00, 0.58);
            vec3  bladeCol = mix(rootCol, tipCol, hT * hT);

            // Per-blade colour variety (±7.5 % hue jitter)
            float variety  = _gHash(cell * 7.3) * 0.15 - 0.075;
            bladeCol      *= (1.0 + variety);

            // ── Lighting ─────────────────────────────────────────────────────
            // Sky ambient squared (matches SDV's own sky calculation)
            float ambient  = skyLight * skyLight * 0.80 + 0.15;

            // Subsurface glow at blade edges (rim translucency)
            vec3  bladeNrm = normalize(cross(v1 - v0, v2 - v0));
            if (dot(bladeNrm, -rd) < 0.0) bladeNrm = -bladeNrm;
            float NdotUp   = dot(bladeNrm, vec3(0.0, 1.0, 0.0));
            float sss      = 0.14 * (1.0 - abs(NdotUp));

            // Root darkening: AO near the soil
            float rootAO   = mix(0.45, 1.0, hT);

            bladeCol *= (ambient + sss) * rootAO;

            // ── Coverage / alpha ──────────────────────────────────────────────
            // Fade horizontal edges of the billboard so it blends cleanly
            float edgeFade = smoothstep(0.0, 0.22, 1.0 - abs(bary.x * 2.0 - 1.0));
            float coverage = edgeFade * distFade;

            // Accept closest hit
            closestT = tHit;
            hitColor = vec4(bladeCol, coverage);
            anyHit   = true;
        }
    }

    return anyHit ? hitColor : vec4(0.0);
}
