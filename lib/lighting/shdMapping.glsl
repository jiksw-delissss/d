// Enable filtering on shadows
const int shadowMapResolution = 512; // Shadow map resolution. Increase for more resolution at the cost of performance. [512 1024 1536 2048 2560 3072 3584 4096 4608 5120 5632 6144 6656 7168 7680 8192]
const float shadowMapPixelSize = 1.5 / shadowMapResolution; // Shadow map pixel size. Calculated as the reciprocal of the shadow map resolution.
const bool shadowHardwareFiltering = true; // Free slightly better filtering

// Increased default to 256.0 so Distant Horizons chunks fall within the shadow frustum.
const float shadowDistance = 256.0; // Shadow distance. Increase to stretch the shadow map to farther distances in blocks. It's recommended to match this setting with your render distance and increase your shadow map resolution. [32.0 64.0 96.0 128.0 160.0 192.0 224.0 256.0 288.0 320.0 352.0 384.0 416.0 448.0 480.0 512.0 544.0 576.0 608.0 640.0 672.0 704.0 736.0 768.0 800.0 832.0 864.0 896.0 928.0 960.0 992.0 1024.0]
const float shadowDistanceRenderMul = 1.0; // Hardcoded to be always 1.0 for maximum optimization.
const float entityShadowDistanceMul = 0.5; // Renders the entity shadows at half shadowDistance. Iris only.

// Shadow opaque
uniform sampler2DShadow shadowtex0;

#ifdef SHADOW_COLOR
    // Shadow w/o translucents
    uniform sampler2DShadow shadowtex1;

    // Shadow color
    uniform sampler2D shadowcolor0;
#endif

// Fast Super Smooth VPS (Variable Penumbra Softening)
#ifndef VPS_ENABLED
#define VPS_ENABLED 1  // Enable/disable VPS
#endif
#ifndef VPS_MIN_SMOOTH
#define VPS_MIN_SMOOTH 0.5  // Minimum smoothing at close range
#endif
#ifndef VPS_MAX_SMOOTH  
#define VPS_MAX_SMOOTH 2.0  // Maximum smoothing at far range
#endif
#ifndef VPS_TRANSITION_DIST
#define VPS_TRANSITION_DIST 64.0  // Distance where smoothing transitions from min to max
#endif

// Fast PCF (Percentage Closer Filtering) with variable kernel size
vec3 getShdColVPSImpl(in vec3 shdPos, in float worldDist){
    float shd0 = 1.0;
    float shd1 = 1.0;
    
    // Calculate VPS kernel size based on distance
    #if VPS_ENABLED == 1
        float vpsFactor = clamp(worldDist / VPS_TRANSITION_DIST, 0.0, 1.0);
        float vpsRadius = mix(VPS_MIN_SMOOTH, VPS_MAX_SMOOTH, vpsFactor) * shadowMapPixelSize;
    #else
        float vpsRadius = VPS_MIN_SMOOTH * shadowMapPixelSize;
    #endif
    
    // Fast 4-tap PCF with rotated grid
    float angle = fract(sin(dot(shdPos.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.28318530718;
    vec2 rotDir = vec2(cos(angle), sin(angle));
    
    // 2 optimized sampleVal positions (diagonals)
    vec2 samples[2];
    samples[0] = vec2( vpsRadius,  vpsRadius);
    samples[1] = vec2(-vpsRadius, -vpsRadius);

    // Apply rotation to all samples
    for(int i = 0; i < 2; i++) {
        samples[i] = vec2(
            samples[i].x * rotDir.x - samples[i].y * rotDir.y,
            samples[i].x * rotDir.y + samples[i].y * rotDir.x
        );
    }

    float sum0 = 0.0;
    float sum1 = 0.0;

    // Sample shadow maps — fixed: was "i < 0" (dead loop), now "i < 2"
    for(int i = 0; i < 2; i++) {
        sum0 += textureLod(shadowtex0, vec3(shdPos.xy + samples[i], shdPos.z), 0);
        #ifdef SHADOW_COLOR
            sum1 += textureLod(shadowtex1, vec3(shdPos.xy + samples[i], shdPos.z), 0);
        #endif
    }

    // Average over 2 samples
    shd0 = sum0 * 0.5;
    #ifdef SHADOW_COLOR
        shd1 = sum1 * 0.5;
    #endif
    
    #ifdef SHADOW_COLOR
        if(shd0 >= 0.999) return vec3(1);
        if(shd1 <= 0.001) return vec3(0);
        vec3 shadowCol = texelFetch(shadowcolor0, ivec2(shdPos.xy * shadowMapResolution), 0).rgb;
        return shadowCol * (1.0 - shd0) * shd1 + shd0;
    #else
        return vec3(shd0);
    #endif
}

// Shadow diffraction helper: applies a warm red/orange fringe along shadow edges
vec3 applyShadowDiffraction(in vec3 baseCol, in vec3 shdPos, in float shdCenter){
    // Only apply diffraction near actual geometry shadow boundaries (shdCenter transitioning 0->1).
    // This gates out caustic/translucent-lit areas (shdCenter ~= 1.0 = lit through water)
    // so their blue tint is never overridden by the reddish fringe.
    float shadowEdge = 1.0 - smoothstep(0.05, 0.95, shdCenter);
    if(shadowEdge < 0.02) return baseCol;

    // Detect the shadow boundary using the shadow depth value gradient (more accurate than luminance)
    vec2 grad = vec2(dFdx(shdCenter), dFdy(shdCenter));
    float gLen = length(grad);
    float edgeThreshold = 0.00001;
    if(gLen <= edgeThreshold) return baseCol;

    float t = smoothstep(edgeThreshold, edgeThreshold * 6.0, gLen) * shadowEdge;

    // Sample slightly offset toward the lit side of the edge
    vec2 dir = normalize(grad);
    vec2 offset = dir * 1.5 * shadowMapPixelSize;
    float sampleVal = textureLod(shadowtex0, vec3(shdPos.xy + offset, shdPos.z), 0);

    // fringeStrength peaks on the lit side of the shadow edge
    float fringeStrength = t * sampleVal;

    // Warm red/orange diffraction tint
    vec3 rim = baseCol;
    rim.r = mix(baseCol.r, 1.0,  clamp(fringeStrength * 2.2, 0.0, 1.0));
    rim.g = mix(baseCol.g, 0.45, clamp(fringeStrength * 1.0, 0.0, 0.6));
    rim.b = mix(baseCol.b, 0.12, clamp(fringeStrength * 0.5, 0.0, 0.3));

    return mix(baseCol, rim, clamp(fringeStrength * 4.5, 0.0, 1.0));
}

// Caustic chromatic aberration: splits caustic brightness ripple into RGB by
// sampling shadowtex1 (translucent shadow) at staggered offsets, then tinting
// each channel. Works even when shadowcolor0 is a flat blue water texture.
vec3 applyCausticChromatic(in vec3 shdPos, in float shd1){
    // Base caustic color from water texture (usually blue-tinted)
    vec3 waterCol = texelFetch(shadowcolor0, ivec2(shdPos.xy * shadowMapResolution), 0).rgb;

    // Sample the caustic brightness ripple (shadowtex1) at 3 staggered positions.
    // Red leads slightly, blue lags — mimicking light dispersion through water.
    float disperse = 1.2 * shadowMapPixelSize;
    float brightR = textureLod(shadowtex1, vec3(shdPos.xy + vec2( disperse, 0.0), shdPos.z), 0);
    float brightG = shd1; // green stays at center (no offset)
    float brightB = textureLod(shadowtex1, vec3(shdPos.xy - vec2( disperse, 0.0), shdPos.z), 0);

    // Detect edge intensity from the brightness difference between channels.
    // Zero in flat areas, high at ripple edges — the actual chromatic split signal.
    float chromaSplit = abs(brightR - brightB) + abs(brightR - brightG) * 0.5;
    float edgeStr = clamp(chromaSplit * 8.0, 0.0, 1.0);

    // Flat caustic (no edge): water color modulated by center brightness
    vec3 flatCaustic = waterCol * shd1;

    // Chromatic caustic: each channel uses its own offset brightness + color tint.
    // Tints disperse toward warm red/orange on one side, cool blue on the other,
    // giving visible RGB fringing even on a monochrome blue water texture.
    vec3 chromaCaustic;
    chromaCaustic.r = waterCol.r * brightR * 1.6 + brightR * 0.35; // warm red boost
    chromaCaustic.g = waterCol.g * brightG * 1.1;                   // green neutral
    chromaCaustic.b = waterCol.b * brightB * 0.85 + brightB * 0.15; // cool blue stays

    // Mix flat -> chromatic based on edge presence
    return mix(flatCaustic, chromaCaustic, edgeStr);
}

vec3 getShdCol(in vec3 shdPos){
    float shd0 = 1.0;
    float shd1 = 1.0;

    #if defined(SHADOW_PENUMBRA) && !defined(FAST_LIGHTING)

            float angle = fract(sin(dot(shdPos.xy, vec2(12.9898,78.233))) * 43758.5453) * 6.28318530718;
            mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

            float sum = 0.0;
            float weightSum = 0.0;
            for(int i = 0; i < 16; ++i){
                vec2 offs = rot * poissonDisk[i] * radiusUV;
                float sampleVal = textureLod(shadowtex0, vec3(shdPos.xy + offs, shdPos.z), 0);
                float w = 1.0 - clamp(length(poissonDisk[i]), 0.0, 1.0);
                w = w * w;
                sum += sampleVal * w;
                weightSum += w;
            }
            shd0 = (weightSum > 0.0) ? sum / weightSum : 1.0;

            #ifdef SHADOW_COLOR
                float sum1 = 0.0;
                float wsum1 = 0.0;
                for(int i = 0; i < 16; ++i){
                    vec2 offs = rot * poissonDisk[i] * radiusUV;
                    float sample1 = textureLod(shadowtex1, vec3(shdPos.xy + offs, shdPos.z), 0);
                    float w = 1.0 - clamp(length(poissonDisk[i]), 0.0, 1.0);
                    w = w * w;
                    sum1 += sample1 * w;
                    wsum1 += w;
                }
                shd1 = (wsum1 > 0.0) ? sum1 / wsum1 : 1.0;
            #endif

    #elif defined(FAST_LIGHTING)
            #if FAST_SHADOW_PENUMBRA == 1
                float angle = fract(sin(dot(shdPos.xy, vec2(12.9898,78.233))) * 43758.5453) * 6.28318530718;
                mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
                float sum = 0.0;
                float wsum = 0.0;
                for(int i = 0; i < FAST_SHADOW_SAMPLES; ++i){
                    vec2 offs = rot * poissonDisk[i] * radiusUV;
                    float s = textureLod(shadowtex0, vec3(shdPos.xy + offs, shdPos.z), 0);
                    float w = 1.0 - clamp(length(poissonDisk[i]), 0.0, 1.0);
                    sum += s * w;
                    wsum += w;
                }
                shd0 = (wsum > 0.0) ? sum / wsum : 1.0;
                #ifdef SHADOW_COLOR
                    float sum1 = 0.0;
                    float wsum1 = 0.0;
                    for(int i = 0; i < FAST_SHADOW_SAMPLES; ++i){
                        vec2 offs = rot * poissonDisk[i] * radiusUV;
                        float s1 = textureLod(shadowtex1, vec3(shdPos.xy + offs, shdPos.z), 0);
                        float w = 1.0 - clamp(length(poissonDisk[i]), 0.0, 1.0);
                        sum1 += s1 * w;
                        wsum1 += w;
                    }
                    shd1 = (wsum1 > 0.0) ? sum1 / wsum1 : 1.0;
                #endif
            #else
                shd0 = textureLod(shadowtex0, shdPos, 0);
                #ifdef SHADOW_COLOR
                    shd1 = textureLod(shadowtex1, shdPos, 0);
                #endif
            #endif

    #else
            shd0 = textureLod(shadowtex0, shdPos, 0);
            #ifdef SHADOW_COLOR
                shd1 = textureLod(shadowtex1, shdPos, 0);
            #endif
    #endif

    #ifdef SHADOW_COLOR
        if(shd0 >= 0.999){
            // Fully lit by opaque geometry — check for caustic (translucent light)
            if(shd1 >= 0.999) return vec3(1); // Fully lit, no caustic
            // Caustic zone: shd0=1 (no opaque blocker) but shd1<1 (water above)
            // Apply chromatic aberration here to give caustics their dispersed color
            return applyCausticChromatic(shdPos, shd1);
        }
        if(shd1 <= 0.001) return vec3(0);
        // Normal colored translucent shadow — diffraction on edges
        vec3 shadowCol = texelFetch(shadowcolor0, ivec2(shdPos.xy * shadowMapResolution), 0).rgb * (1.0 - shd0) * shd1 + shd0;
        return applyShadowDiffraction(shadowCol, shdPos, shd0);

    #else
        return vec3(shd0);
    #endif
}

vec3 getShdColVPS(in vec3 shdPos, in float worldDist){
    #if VPS_ENABLED == 1
        return getShdColVPSImpl(shdPos, worldDist);
    #else
        return getShdCol(shdPos);
    #endif
}

vec3 getShdCol(in vec3 shdPos, in float dither){
    float r = shadowMapPixelSize;
    vec2 randVec0 = vec2(cos(dither + 0.00), sin(dither + 0.00)) * r;
    vec2 randVec1 = vec2(cos(dither + 1.73), sin(dither + 1.21)) * r;
    vec2 randVec2 = vec2(cos(dither + 2.89), sin(dither + 2.57)) * r;
    vec2 randVec3 = vec2(cos(dither + 4.13), sin(dither + 3.47)) * r;
    vec2 randVec4 = vec2(cos(dither + 5.29), sin(dither + 4.67)) * r;
    vec2 randVec5 = vec2(cos(dither + 6.71), sin(dither + 5.83)) * r;
    vec2 randVec6 = vec2(cos(dither + 7.37), sin(dither + 6.19)) * r;
    vec2 randVec7 = vec2(cos(dither + 8.23), sin(dither + 7.41)) * r;
    vec2 randVec8 = vec2(cos(dither + 9.11), sin(dither + 8.03)) * r;

    vec3 s0 = getShdCol(vec3(shdPos.xy + randVec0, shdPos.z));
    vec3 s1 = getShdCol(vec3(shdPos.xy + randVec1, shdPos.z));
    vec3 s2 = getShdCol(vec3(shdPos.xy + randVec2, shdPos.z));
    vec3 s3 = getShdCol(vec3(shdPos.xy + randVec3, shdPos.z));
    vec3 s4 = getShdCol(vec3(shdPos.xy + randVec4, shdPos.z));
    vec3 s5 = getShdCol(vec3(shdPos.xy + randVec5, shdPos.z));
    vec3 s6 = getShdCol(vec3(shdPos.xy + randVec6, shdPos.z));
    vec3 s7 = getShdCol(vec3(shdPos.xy + randVec7, shdPos.z));
    vec3 s8 = getShdCol(vec3(shdPos.xy + randVec8, shdPos.z));

    return (s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8) * (1.0 / 9.0);
}