const uint volumetricCloudSteps = uint(VOLUMETRIC_CLOUD_STEPS);
const float volumetricCenterDepth = 0.0 * 0.5;
const float volumetricCloudHeight = 1536.0;
#define CLOUD_FILL 100.6

// Fixed render distance for clouds (in blocks)
#define CLOUD_RENDER_DISTANCE 18000000.0 

// ShaderToy-like lighting/shape tuning constants
const float VC_TRANSMISSION_FACTOR = 0.35;
const float VC_ABSORPTION_FACTOR = 0.45;
const float VC_DENSITY_DISTANCE_SCALE = 10.0;
const float VC_CLOUD_DENSITY_SCALE = 0.00012;
const float VC_CLOUD_OPACITY_SCALE = 1.75;
const float VC_EDGE_HIGHLIGHT_FACTOR = 1.5;
const float VC_AMBIENT_INTENSITY = 1.22;
const float VC_SUN_INTENSITY = 1.2;
const float VC_CLOUD_HEIGHT_REFERENCE = 6144.0;
const float VC_CLOUD_HEIGHT_SCALE_MAX = 8.0;
const float VC_CLOUD_HEIGHT_SCALE_MIN = 0.25;
// Time-driven animation knobs
const float VC_SHAPE_TIME_SCALE = 0.45;
const float VC_BULGE_TIME_SCALE = 0.9;
const float VC_SHAPE_AMPLITUDE = 0.12;
const float VC_BULGE_AMPLITUDE = 0.06;

// ============================================================================
// Volumetric Clouds — HIGHLY COMPLEX OPTIMIZED 3D PROCEDURAL RAYMARCH
// ============================================================================

// ── Procedural 3D Hash & Noise ────────────────────────────────────────────────
float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float noise3D(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // Quintic

    float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(i + vec3(1.0, 1.0, 1.0));

    return mix(
        mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
        mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
        f.z
    );
}

// Include guard
#ifndef HENYEY_GREENSTEIN_DEFINED
#define HENYEY_GREENSTEIN_DEFINED
float henyeyGreenstein(float cosAngle, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0 * g * cosAngle, 1.5));
}
float cloudPhaseFunction(float cosAngle, float g) {
    return henyeyGreenstein(cosAngle, g) * 1.5;
}
#endif

#define VC_SLAB_MULT 32.0

float _vc_cloudSizeScale() {
    return clamp(VC_CLOUD_HEIGHT_REFERENCE / volumetricCloudHeight,
                 VC_CLOUD_HEIGHT_SCALE_MIN,
                 VC_CLOUD_HEIGHT_SCALE_MAX);
}

// ============================================================================
// ULTRA-COMPLEX CUMULUS DENSITY MODEL (Double Warp & High-Frequency Detail)
// ============================================================================
float getCloudDensity(vec3 worldPos, float h, float t) {
    // FIX: Reversed time to make clouds move backward
    t = -t;

    // FIX: Reduced top smoothstep so clouds keep their massive 3D volume
    float heightGrad = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.6, 1.0, h));
    
    #ifndef FORCE_DISABLE_WEATHER
    float rainEff = rainStrength * rainStrength;
    float rainHeightGrad = smoothstep(0.0, 0.02, h) * (1.0 - smoothstep(0.95, 1.0, h));
    heightGrad = mix(heightGrad, rainHeightGrad, rainEff);
    #endif

    if(heightGrad < 0.001) return 0.0;

    float cloudSizeScale = _vc_cloudSizeScale();

    vec3 windDir = normalize(vec3(1.0, 0.0, 0.6));
    vec3 wind1 = windDir * (t * 3.0);
    vec3 wind2 = windDir * (t * 6.0);
    vec3 wind3 = windDir * (t * 12.0);

    // FIX: Restored slow vertical frequency (0.008) for massive 3D volume
    vec3 p = vec3(worldPos.xz * cloudSizeScale * 0.0015, worldPos.y * 0.008);

    // ── DOUBLE DOMAIN WARP (Extreme organic complexity, no twirls) ──────────
    vec3 morph = vec3(t * 1.0, t * 0.8, t * 1.2);
    vec3 q = vec3(
        noise3D(p + wind1 + morph + vec3(1.5, 8.2, 3.1)),
        noise3D(p + wind1 + morph + vec3(4.2, 2.9, 6.5)),
        noise3D(p + wind1 + morph + vec3(7.1, 5.3, 1.8))
    ) - 0.5;
    p += q * 0.25; 

    vec3 r = vec3(
        noise3D(p * 2.0 + wind2 + vec3(11.5, 18.2, 13.1)),
        noise3D(p * 2.0 + wind2 + vec3(14.2, 12.9, 16.5)),
        noise3D(p * 2.0 + wind2 + vec3(17.1, 15.3, 11.8))
    ) - 0.5;
    p += r * 0.15;

    // ── COVERAGE (Tuned for LESS CLOUDS but BIGGER/WIDER) ──────────────────
    float coverage = noise3D(p * 0.2 + 5.0 + wind1); 
    coverage = clamp(coverage * 1.8 - 0.1, 0.0, 1.5); 
    
    #ifndef FORCE_DISABLE_WEATHER
    coverage = mix(coverage, 1.5, rainEff); 
    #endif
    
    if (coverage < 0.02) return 0.0;

    // ── BASE SHAPE (3 octaves for performance balance) ─────────────────────
    float baseShape = noise3D(p + wind1) * 0.5 
                    + noise3D(p * 2.0 + wind2) * 0.25 
                    + noise3D(p * 4.0 + wind3) * 0.125;

    // ── HZD DENSITY EQUATION ───────────────────────────────────────────────
    float density = max(0.0, coverage - (1.0 - baseShape)) * heightGrad;

    // ── REALISTIC WISPY EROSION & FINE DETAIL ──────────────────────────────
    if (density > 0.01) {
        // FIX: Increased top cauliflower erosion for massive 3D shapes
        float topErosion = noise3D(p * 4.0 + r * 1.5 + wind2);
        density -= topErosion * 0.4 * smoothstep(0.2, 1.0, h);
        
        // Bottom hanging wisps
        float bottomErosion = noise3D(p * 4.0 + r * 1.2 + wind1 + 10.0);
        density -= bottomErosion * 0.35 * (1.0 - smoothstep(0.0, 0.5, h));
    }

    density = clamp(density, 0.0, 1.0);
    return density * VC_CLOUD_DENSITY_SCALE;
}

// ── Cheap density for shadow rays (Optimized 1-octave) ───────────────────────
float getCloudDensityCheap(vec3 worldPos, float h, float t) {
    // FIX: Reversed time to make clouds move backward
    t = -t;

    float heightGrad = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.6, 1.0, h));
    
    #ifndef FORCE_DISABLE_WEATHER
    float rainEff = rainStrength * rainStrength;
    float rainHeightGrad = smoothstep(0.0, 0.02, h) * (1.0 - smoothstep(0.95, 1.0, h));
    heightGrad = mix(heightGrad, rainHeightGrad, rainEff);
    #endif

    if(heightGrad < 0.001) return 0.0;

    float cloudSizeScale = _vc_cloudSizeScale();
    
    vec3 windDir = normalize(vec3(1.0, 0.0, 0.6));
    vec3 wind1 = windDir * (t * 3.0);
    
    // Matched slow vertical frequency
    vec3 p = vec3(worldPos.xz * cloudSizeScale * 0.0015, worldPos.y * 0.008);

    // Matched warp
    vec3 morph = vec3(t * 1.0, t * 0.8, t * 1.2);
    float q = noise3D(p + wind1 + morph + vec3(1.5, 8.2, 3.1)) - 0.5;
    p += q * 0.25; 

    // Matched coverage changes
    float coverage = noise3D(p * 0.2 + 5.0 + wind1);
    coverage = clamp(coverage * 1.8 - 0.1, 0.0, 1.5);

    #ifndef FORCE_DISABLE_WEATHER
    coverage = mix(coverage, 1.5, rainEff); 
    #endif

    if (coverage < 0.02) return 0.0;

    // 1 octave
    float baseShape = noise3D(p + wind1);
    float density = max(0.0, coverage - (1.0 - baseShape)) * heightGrad;
    return density * VC_CLOUD_DENSITY_SCALE;
}

// ============================================================================
// REWORKED HZD / UE4 MULTI-SCATTERING PBR LIGHTING MODEL (Accurate Direction)
// ============================================================================
vec3 vc_skyRenderLighting(
    vec3  rayPos,
    float h,
    float dens,
    float ds, 
    vec3  viewDir,
    vec3  sunDir,
    float sunHeight,
    float lowSunFactor,
    float sunViewDot,
    float sunGlowFactor,
    float sunProximity,
    float antiSunFactor,
    vec3  directSunColor,
    vec3  atmosAmbient,
    vec3  atmosHorizSun,
    vec3  atmosHorizAnti,
    vec3  atmosDown,
    vec3  atmosUp,
    float cyc, 
    float t3D)
{
    // ── 1. DUAL-LOBE HENYEY-GREENSTEIN PHASE FUNCTION ──────────────────────
    float cosAngle = clamp(dot(viewDir, sunDir), -1.0, 1.0);
    float phaseForward = henyeyGreenstein(cosAngle, 0.6);
    float phaseBackward = henyeyGreenstein(cosAngle, -0.4);
    float phase = mix(phaseForward, phaseBackward, 0.2);

    // ── 2. BEER-LAMBERT & POWDER EFFECT ────────────────────────────────────
    float beer = exp(-ds * 5.0); 
    float powder = 1.0 - exp(-ds * 1.5);
    float lightEnergy = beer * 0.9 + powder * 0.1;

    // ── 3. SILVER LINING ────────────────────────────────────────────────────
    float silverLining = pow(sunViewDot, 4.0) * (1.0 - beer) * smoothstep(0.0, 0.4, sunHeight);

    // ── 4. HEMISPHERIC AMBIENT OCCLUSION ───────────────────────────────────
    float ambientAO = exp(-ds * 0.6);

    // ── 5. DIRECTIONAL SKY SCATTERED AMBIENT ───────────────────────────────
    vec3 ambientSky = mix(atmosHorizAnti, atmosUp, h);
    
    vec3 nightAmbient = vec3(0.04, 0.06, 0.09) * (1.0 - cyc);
    ambientSky = max(ambientSky, nightAmbient);
    
    float ambientDir = dot(viewDir, sunDir) * 0.5 + 0.5;
    ambientSky = mix(ambientSky, atmosHorizSun, ambientDir * 0.3 + lowSunFactor * 0.2);
    ambientSky = mix(ambientSky, atmosAmbient, 0.5); 
    
    vec3 ambient = ambientSky * 0.8;
    ambient *= ambientAO;
    ambient += silverLining * atmosHorizSun * 0.5;

    #ifndef FORCE_DISABLE_WEATHER
    float rainEff = rainStrength * rainStrength; 
    vec3 rainColor = vec3(0.12, 0.12, 0.15) * (0.4 + cyc * 0.6);
    ambient = mix(ambient, rainColor, rainEff);
    #endif

    // ── 6. DIRECT SUN/MOON LIGHTING ────────────────────────────────────────
    vec3 sunLit = directSunColor * lightEnergy * (0.6 + 1.2 * phase);
    sunLit += directSunColor * silverLining * 1.5;

    #ifndef FORCE_DISABLE_WEATHER
    sunLit *= (1.0 - rainEff * 0.8);
    #endif

    return clamp(ambient + sunLit, vec3(0.0), vec3(10.0));
}

// ── 2D base haze (kept for compatibility) ─────────────────────────────────────
float sampleCloudDensity(vec3 pos, float time) {
    float density = 0., amp = 2., freq = 0.1, maxA = 0.;
    vec2 wind = vec2(sin(time * 0.015), cos(time * 0.012)) * time * 0.08;
    for (int i = 0; i < 5; i++) {
        float s = fbm2((pos.xz + wind) * freq * 0.04);
        if (i == 0) s = pow(s, 1.1);
        s *= smoothstep(-60., 60., pos.y);
        density += s * amp; maxA += amp; amp *= 0.; freq *= 2.1;
    }
    return density / maxA;
}

// ── Main ──────────────────────────────────────────────────────────────────────
vec4 volumetricClouds(in vec3 nFeetPlayerPos, in vec3 cameraPos,
                      in float feetPlayerDist, in float dither, in bool isSky)
{
    float slabTop    = 0.0;
    float slabBottom = -VOLUMETRIC_CLOUD_DEPTH * VC_SLAB_MULT;
    float slabRange  = slabTop - slabBottom;

    float cloudFar = CLOUD_RENDER_DISTANCE;
    if (!isSky && feetPlayerDist > 0.0) {
        cloudFar = min(cloudFar, feetPlayerDist * 0.95);
    }
    
    float lowerB   = (slabBottom - cameraPos.y) / nFeetPlayerPos.y;
    float higherB  = (slabTop    - cameraPos.y) / nFeetPlayerPos.y;
    float nearP    = max(min(lowerB, higherB), 0.0);
    float farP     = min(cloudFar, max(lowerB, higherB));
    if (farP <= nearP) return vec4(0.0);

    float dist  = farP - nearP;

    // FIX: Kept smaller step size to prevent banding, but optimized loop count
    uint steps = uint(clamp(dist / 25.0, 24.0, float(volumetricCloudSteps) * 0.75));
    float initialStepSize = dist / float(steps);
    
    vec3 rayPos = cameraPos + nFeetPlayerPos * nearP + nFeetPlayerPos * (initialStepSize * dither);
    vec3 viewDir = normalize(nFeetPlayerPos);

    // FIX: Check actual sun elevation to properly flip to moon at night
    vec3 originalSunDir = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
    bool isNight = originalSunDir.y < 0.0;
    
    // Use moon direction if it is night
    vec3 sunDir = isNight ? -originalSunDir : originalSunDir;

    float t3D = mod(fragmentFrameTime * 0.02, 10000.0);

    float sunHeight = max(0.01, sunDir.y);

    // FIX: Shift sunset timing backward so clouds turn orange earlier (before horizon)
    float lowSunFactor = clamp((0.35 - sunHeight) / 0.35, 0.0, 1.0);

    float sunViewDot = clamp(dot(normalize(nFeetPlayerPos), sunDir), 0.0, 1.0);
    float sunProximity = sunViewDot * sunViewDot * sunViewDot;

    #ifndef FORCE_DISABLE_DAY_CYCLE
        float sunGlowFactor = sunViewDot * sunViewDot * dayCycle;
        float cyc = dayCycle;
    #else
        float sunGlowFactor = sunViewDot * sunViewDot;
        float cyc = 1.0;
    #endif

    float antiSunFactor = clamp(1.0 - sunViewDot, 0.0, 1.0);

    vec3 horizSunDir = normalize(vec3(sunDir.x, 0.02, sunDir.z));
    vec3 atmosHorizSun = clamp(seusAtmosphere(horizSunDir, sunDir), vec3(0.0), vec3(5.0));
    vec3 atmosUp = clamp(seusAtmosphere(vec3(0.0, 1.0, 0.0), sunDir), vec3(0.0), vec3(4.0));
    vec3 atmosHorizAnti = clamp(seusAtmosphere(-horizSunDir, sunDir), vec3(0.0), vec3(3.0));

    vec3 atmosDown = mix(atmosHorizAnti, atmosHorizSun, lowSunFactor);
    vec3 atmosViewDir = mix(atmosUp, atmosHorizSun, sunGlowFactor * 0.65);
    float antiSqrd = antiSunFactor * antiSunFactor;
    vec3 atmosAmbient = mix(atmosViewDir, atmosHorizAnti * 0.7, antiSqrd * antiSunFactor * 0.4);

    #ifdef FORCE_DISABLE_DAY_CYCLE
        vec3 directSunColor = lightCol * 2.2;
    #else
        // FIX: Use dim moon color at night (0.8 instead of 2.0)
        vec3 directSunColor = mix(moonCol * 10.8,
                                  mix(sunCol * 2.0, atmosHorizSun * 1.0,
                                      lowSunFactor * 0.9 + sunProximity * 0.1),
                                  dayCycleAdjust);
    #endif
    directSunColor = mix(directSunColor, directSunColor * vec3(1.4, 0.9, 0.5), lowSunFactor * 0.8);

    #ifndef FORCE_DISABLE_WEATHER
        float rainEff = rainStrength * rainStrength;
        directSunColor = mix(directSunColor, directSunColor * 0.2, rainEff);
    #endif

    vec3 accumColor = vec3(0.0);
    float accumAlpha = 0.0;
    float trans = 1.0;

    float currentDist = nearP + initialStepSize;
    float stepSize = initialStepSize;

    // ── Raymarch ──────────────────────────────────────────────────────────────
    for (uint i = 0u; i < steps; ++i) {
        if (currentDist > cloudFar) break;

        float distanceFade = 1.0 - smoothstep(cloudFar * 0.85, cloudFar, currentDist);
        float h = clamp((rayPos.y - slabBottom) / slabRange, 0.0, 1.0);

        float dens = getCloudDensity(rayPos, h, t3D);
        dens = clamp(dens * CLOUD_FILL, 0.0, 1.0) * distanceFade;

        if (dens > 0.0001) {
            // 4 steps instead of 2 for smoother directional light
            float lightStepSize = slabRange / 8.0; 
            
            float lightEnergy = 0.0;
            for (int s = 0; s < 4; ++s) {
                vec3 sp = rayPos + sunDir * (lightStepSize * float(s + 1) * 2.0);
                float sh = clamp((sp.y - slabBottom) / slabRange, 0.0, 1.0);
                float cheapDens = getCloudDensityCheap(sp, sh, t3D) * CLOUD_FILL;
                lightEnergy += clamp(cheapDens, 0.0, 1.0) * (lightStepSize * 2.0);
            }
            lightEnergy += dens * stepSize;

            vec3 sampleCol = vc_skyRenderLighting(
                rayPos, h, dens, lightEnergy,
                viewDir, sunDir,
                sunHeight, lowSunFactor,
                sunViewDot, sunGlowFactor, sunProximity, antiSunFactor,
                directSunColor, atmosAmbient,
                atmosHorizSun, atmosHorizAnti, atmosDown, atmosUp,
                cyc, t3D);

            float aerialPerspective = smoothstep(cloudFar * 0.5, cloudFar, currentDist);
            vec3 skyFogColor = mix(atmosHorizSun, atmosUp, clamp(viewDir.y * 2.0, 0.0, 1.0));
            sampleCol = mix(sampleCol, skyFogColor, aerialPerspective * 0.4);

            // Solid clouds, adjusted multiplier to prevent harsh banding on edges
            float alpha = 1.0 - exp(-dens * stepSize * 6.0);
            alpha = clamp(alpha, 0.0, 1.0);

            accumColor += sampleCol * alpha * trans;
            trans *= (1.0 - alpha);
            accumAlpha = 1.0 - trans;

            if (trans < 0.02) break;
        }

        // Exponential stepping
        rayPos += nFeetPlayerPos * stepSize;
        currentDist += stepSize;
        // FIX: Very slow growth (1.05 instead of 1.06) to maintain 3D detail on the sides
        stepSize *= 1.05; 
    }

    return vec4(accumColor, accumAlpha);
}

// ============================================================================
// VOLUMETRIC CLOUD SHADOW — Cast accurate cloud shadows on terrain
// ============================================================================
float getVolumetricCloudShadow(in vec3 worldPos, in vec3 sunDir, in vec3 cameraPos,
                                float slabTop, float slabBottom, float t3D)
{
    if (sunDir.y < 0.01) return 1.0;

    float slabRange = slabTop - slabBottom;

    float tEnter = (slabBottom - worldPos.y) / sunDir.y;
    float tExit = (slabTop - worldPos.y) / sunDir.y;

    if (tExit <= 0.0) return 1.0;

    tEnter = max(tEnter, 0.0);
    tExit = max(tExit, 0.0);

    if (worldPos.y >= slabBottom && worldPos.y <= slabTop) {
        tEnter = 0.0;
    }

    if (tExit <= tEnter) return 1.0;

    // OPTIMIZATION: 2 shadow steps instead of 4
    const uint shadowSteps = 4u; 
    float rayDist = tExit - tEnter;
    vec3 stepVec = sunDir * (rayDist / float(shadowSteps));
    vec3 rayPos = worldPos + sunDir * tEnter;

    float opticalDepth = 0.0;

    for (uint i = 0u; i < shadowSteps; ++i) {
        float h = clamp((rayPos.y - slabBottom) / slabRange, 0.0, 1.0);
        float dens = getCloudDensityCheap(rayPos, h, t3D);
        dens = clamp(dens * CLOUD_FILL, 0.0, 1.0);

        opticalDepth += dens * (rayDist / float(shadowSteps)) * 1.6; 

        if (opticalDepth > 3.0) return 0.35;

        rayPos += stepVec;
    }

    float transmittance = exp(-opticalDepth * 1.8);
    return max(transmittance, 0.008); 
}