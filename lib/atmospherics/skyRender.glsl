#ifndef VOLCUMETRIC_CLOUDS_GLSL
#define VOLCUMETRIC_CLOUDS_GLSL

#define time fragmentFrameTime

// Fallback for dimensions that don't define day/night uniforms

#if CLOUD_TYPE != 0 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT

// Enhanced cloud morphing & mixing controls
#ifndef CLOUD_MORPH_SPEED
#define CLOUD_MORPH_SPEED 0.7
#endif
#ifndef CLOUD_MIX_SPEED
#define CLOUD_MIX_SPEED 0.7
#endif
#ifndef CLOUD_SECONDARY_SCALE
#define CLOUD_SECONDARY_SCALE 1.6
#endif
#ifndef CLOUD_MIX_AMOUNT
#define CLOUD_MIX_AMOUNT 1.0
#endif
#ifndef CLOUD_FILL
#define CLOUD_FILL 1.6
#endif
#ifndef CLOUD_DETAIL_SCALE
#define CLOUD_DETAIL_SCALE 1.0
#endif
#ifndef CLOUD_TURBULENCE_AMOUNT
#define CLOUD_TURBULENCE_AMOUNT 1.25
#endif


    // 2D hash and noise
    float hash21(in vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
    float noise21(in vec2 p){
        vec2 i = floor(p);
        vec2 f = fract(p);
        float a = hash21(i + vec2(0.0,0.0));
        float b = hash21(i + vec2(1.0,0.0));
        float c = hash21(i + vec2(0.0,1.0));
        float d = hash21(i + vec2(1.0,1.0));
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    float fbm2(in vec2 p){
        float v = 0.0;
        float a = 0.5;
        for(int i = 0; i < 4; i++){
            v += a * noise21(p);
            p = mat2(1.6, -1.2, 1.2, 1.6) * p * 1.9;
            a *= 0.5;
        }
        return v;
    }

    // Cloud density computed by integrating layered fbm along the view ray
    vec2 cloudVolume(in vec3 dir, in vec2 uv, in float time){
        const int STEPS = 3;
        const float START = 0.15;
        const float END = 2.0;
        const float SCALE = 2.5;
        const float DETAIL = 1.015;

        float sum = 0.0;
        float weight = 1.0;
        float t = START;
        float dt = (END - START) / float(STEPS);

        float morphTime  = time * 0.18;
        float mixTime    = time * 0.12;
        float detailTime = time * 1.08;

        vec2 windVariation = vec2(
            sin(time * 0.05) * 0.3,
            cos(time * 0.07) * 0.2
        );

        for(int i = 0; i < STEPS; i++){
            float stepTime = time + float(i) * 0.7;

            vec3 basePos = vec3(dir.xy * (SCALE * t) + uv * 0.15, t * 0.6 + time * 0.03);

            vec2 turbulence = vec2(
                sin(basePos.z * 1.5 + stepTime * 0.2) * 0.15,
                cos(basePos.z * 1.2 + stepTime * 0.15) * 0.12
            ) * CLOUD_TURBULENCE_AMOUNT;

            vec3 p = basePos + vec3(turbulence + windVariation, 0.0);

            float baseA = fbm2(p.xy * 0.75 + vec2(stepTime * 0.04, 0.0));
            float baseB = fbm2(p.xy * 0.82 + vec2(0.0, stepTime * 0.03));

            float angC = float(i) * 0.21 + stepTime * 0.01;
            mat2 rotC = mat2(cos(angC), -sin(angC), sin(angC), cos(angC));
            float baseC = fbm2(rotC * (p.xy * 0.68) + vec2(stepTime * 0.02));

            float detail1 = fbm2(p.xy * CLOUD_DETAIL_SCALE + vec2(51.3, 7.1) + detailTime * 0.1);
            float detail2 = fbm2(p.xy * (CLOUD_DETAIL_SCALE * 1.7) + vec2(23.7, 42.9) + detailTime * 0.08);
            float combinedDetail = mix(detail1, detail2, 0.4) * 0.6 + detail1 * 0.4;

            float morph1 = 0.5 + 0.5 * sin(morphTime * CLOUD_MORPH_SPEED * 1.3 + dot(uv, vec2(0.37,0.61)) * 0.8 + float(i) * 0.31);
            float morph2 = 0.5 + 0.5 * cos(morphTime * CLOUD_MORPH_SPEED * 0.7 + dot(uv, vec2(0.21,0.89)) * 0.6 + float(i) * 0.42);

            float shapeAB     = mix(baseA, baseB, smoothstep(0.0, 1.0, morph1));
            float blendedBase = mix(shapeAB, baseC, smoothstep(0.0, 1.0, morph2));

            float secondary1 = fbm2(p.xy * CLOUD_SECONDARY_SCALE + vec2(13.7, 9.2) + mixTime * 0.05);
            float secondary2 = fbm2(p.xy * (CLOUD_SECONDARY_SCALE * 0.6) + vec2(31.4, 17.3) + mixTime * 0.03);
            float secondary3 = fbm2(p.xy * (CLOUD_SECONDARY_SCALE * 1.3) + vec2(7.9, 23.6) + mixTime * 0.04);
            float combinedSecondary = (secondary1 * 0.5 + secondary2 * 0.3 + secondary3 * 0.2);

            float densityMain = smoothstep(0.4, 0.78, blendedBase + 0.45 * combinedDetail);

            float mixOsc1 = 0.5 + 0.5 * sin(mixTime * CLOUD_MIX_SPEED * 0.9 + dot(uv, vec2(0.21,0.47)) * 0.7);
            float mixOsc2 = 0.5 + 0.5 * cos(mixTime * CLOUD_MIX_SPEED * 1.2 + dot(uv, vec2(0.67,0.33)) * 0.5);
            float dynamicMixAmount = mix(mixOsc1, mixOsc2, 0.5) * CLOUD_MIX_AMOUNT;

            float combinedDensity = mix(densityMain, clamp(combinedSecondary * 0.85, 0.0, 1.0), dynamicMixAmount);

            float wispyFactor = pow(combinedDetail, 2.0) * 0.3;
            combinedDensity = combinedDensity * (1.0 - wispyFactor) + wispyFactor * 0.7;

            float heightVariation = 1.0 + sin(p.z * 1.5 + time * 0.1) * 0.15;
            float heightFade = exp(-t * 0.7) * heightVariation;

            sum += combinedDensity * weight * heightFade;

            weight *= mix(0.75, 0.82, fract(float(i) * 0.37 + time * 0.01));
            t += dt;
        }

        float dens = clamp(sum * 0.35, 0.0, 1.0);
        dens = pow(dens, 1.05);
        dens = smoothstep(0.06, 0.92, dens);

        float largeScaleVariation = fbm2(uv * 0.1 + time * 0.001) * 0.2 + 0.9;
        dens *= largeScaleVariation;
        dens = clamp(dens * CLOUD_FILL, 0.0, 1.0);

        return vec2(dens, 0.0);
    }

    // SEUS-derived helpers
    float Get2DNoise(in vec3 pos) {
        vec2 p = floor(pos.xz + 0.5);
        vec2 f = fract(pos.xz + 0.5);
        f.x = f.x * f.x * (3.0 - 2.0 * f.x);
        f.y = f.y * f.y * (3.0 - 2.0 * f.y);
        vec2 uv = (p + f + 0.5) / float(64);
        return texture2D(noisetex, uv).x;
    }

    float Get3DNoise(in vec3 pos) {
        vec3 p = floor(pos + 0.5);
        vec3 f = fract(pos + 0.5);
        f = f * f * (3.0 - 2.0 * f);
        vec2 uv = (p.xy + p.z * vec2(17.0)) + f.xy;
        vec2 coord = (uv + 0.5) / float(64);
        vec2 coord2 = (uv + vec2(17.0) + 0.5) / float(64);
        float xy1 = texture2D(noisetex, coord).x;
        float xy2 = texture2D(noisetex, coord2).x;
        return mix(xy1, xy2, f.z);
    }

    float GetCoverage(in float coverage, in float density, in float clouds) {
        clouds = clamp(clouds - (1.0 - coverage), 0.0, 1.0 - density) / (1.0 - density);
        clouds = max(0.0, clouds * 1.1 - 0.1);
        clouds = clouds * clouds * (3.0 - 2.0 * clouds);
        return clouds;
    }

    float CalculateSunglow(vec3 npos, vec3 lightVector) {
        vec3 halfVector2 = normalize(-lightVector + npos);
        float factor = 1.0 - dot(halfVector2, npos);
        return factor * factor * factor * factor;
    }

    vec4 SEUS_CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness) {
        float cloudHeight = altitude;
        float cloudDepth  = thickness;

        vec3 p = worldPosition.xyz / 150.0;
        float t = fragmentFrameTime * 1.0;
        p += (Get2DNoise(p * 2.0 + vec3(0.0, t * 0.00, 0.0)) * 2.0 - 1.0) * 0.10;
        p.z -= (Get2DNoise(p * 0.25 + vec3(0.0, t * 0.00, 0.0)) * 2.0 - 1.0) * 0.45;
        p.x -= (Get2DNoise(p * 0.125 + vec3(0.0, t * 0.00, 0.0)) * 2.0 - 1.0) * 2.2;
        p.xz -= (Get2DNoise(p * 0.0525 + vec3(0.0, t * 0.00, 0.0)) * 2.0 - 1.0) * 2.7;
        p.x *= 0.5;
        p.x -= t * 0.01;

        vec3 p1 = p * vec3(1.0, 0.5, 1.0)  + vec3(0.0, t * 0.01, 0.0);
        float noise  = Get2DNoise(p * vec3(1.0, 0.5, 1.0) + vec3(0.0, t * 0.01, 0.0));
        p *= 2.0; p.x -= t * 0.057; vec3 p2 = p;
        noise += (2.0 - abs(Get2DNoise(p) * 2.0 - 0.0)) * (0.15); p *= 3.0; p.xz -= t * 0.035; p.x *= 2.0; vec3 p3 = p;
        noise += (3.0 - abs(Get2DNoise(p * 3.0 - 0.0))) * (0.050); p *= 3.0; p.xz -= t * 0.035; vec3 p4 = p;
        noise += (3.0 - abs(Get2DNoise(p * 3.0 - 0.0))) * (0.015); p *= 3.0; p.xz -= t * 0.035;
        noise += ((Get2DNoise(p))) * (0.022); p *= 3.0; noise += ((Get2DNoise(p))) * (0.009);
        noise /= 1.475;

        float coverage = 0.701;
        coverage = mix(coverage, 0.97, rainStrength);
        float dist = length(worldPosition.xz - cameraPosition.xz * 0.5);
        coverage *= max(0.0, 1.0 - dist / 14000.0);
        float density = 0.1 + rainStrength * 0.3;

        noise = GetCoverage(coverage, density, noise);

        float sundiff = Get2DNoise(p1 + worldLightVector.xyz * 0.4);
        sundiff += (2.0 - abs(Get2DNoise(p2 + worldLightVector.xyz * 0.2) * 2.0 - 0.0)) * (0.55);
        float largeSundiff = sundiff;
        largeSundiff = -GetCoverage(coverage, 0.0, largeSundiff * 1.3);
        sundiff += (3.0 - abs(Get2DNoise(p3 + worldLightVector.xyz * 0.08) * 3.0 - 0.0)) * (0.045);
        sundiff += (3.0 - abs(Get2DNoise(p4 + worldLightVector.xyz * 0.05) * 3.0 - 0.0)) * (0.015);
        sundiff /= 1.5;
        sundiff *= max(0.0, 1.0 - dist / 14000.0);
        sundiff = -GetCoverage(coverage * 1.0, 0.0, sundiff);
        float secondOrder = pow(clamp(sundiff * 1.1 + 1.45, 0.0, 1.0), 4.0);
        float firstOrder  = pow(clamp(largeSundiff * 1.1 + 1.66, 0.0, 1.0), 3.0);

        float directLightFalloff = firstOrder * secondOrder;
        float anisoBackFactor = mix(clamp(pow(noise, 1.6) * 2.5, 0.0, 1.0), 1.0, pow(sunglow, 1.0));
        directLightFalloff *= anisoBackFactor;
        directLightFalloff *= mix(11.5, 1.0, pow(sunglow, 0.5));

        vec3 colorDirect = sunCol * 11.215;
        colorDirect = mix(colorDirect, colorDirect * vec3(0.2,0.2,0.2), 1.0 - dayCycle);
        colorDirect *= 1.0 + pow(sunglow, 2.0) * 120.0 * pow(directLightFalloff, 1.1) * (1.0 - rainStrength * 0.8);

        vec3 colorAmbient = mix(skyCol, sunCol * 2.0, vec3(0.12)) * 0.80;
        colorAmbient = mix(colorAmbient, vec3(0.4) * (dot(skyCol, vec3(0.2126,0.7152,0.0722))), vec3(rainStrength));
        colorAmbient *= mix(1.0, 0.3, 1.0 - dayCycle);
        colorAmbient = mix(colorAmbient, colorAmbient * 3.0 + sunCol * 0.05, vec3(clamp(pow(1.0 - noise, 12.0) * 1.0, 0.0, 1.0)));

        vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0, directLightFalloff)));
        color *= 1.0;
        color = mix(color, color * 0.9, rainStrength);

        return vec4(color.rgb, noise);
    }

    vec3 seusAtmosphere(vec3 rayDir, vec3 lightDir); // Forward declaration

    // Forward-declare volumetric clouds so this file can call it when
    // the implementation is included later (composite pass includes it).
    vec4 volumetricClouds(in vec3 nFeetPlayerPos, in vec3 cameraPos,
                          in float feetPlayerDist, in float dither, in bool isSky);

    // ── 3D Cumulus Cloud Density ─────────────────────────────────────────────
    float cumulusDensity(vec2 pos, float h, float time) {
        float heightGrad = smoothstep(0.0, 0.18, h) * smoothstep(1.0, 0.55, h);
        if(heightGrad < 0.001) return 0.0;

        float coarse = fbm2(pos * 0.22 + vec2(time * 0.012, time * 0.009));
        float mid    = fbm2(pos * 0.58 + vec2(time * 0.025, -time * 0.018) + 3.7);
        float fine   = fbm2(pos * 1.35 + vec2(-time * 0.04, time * 0.031) + 7.3);

        float base = coarse * 0.62 + mid * 0.28 + fine * 0.10;

        float cov = CLOUD_FILL * 0.62;
        base = smoothstep(0.48 - cov * 0.18, 0.82, base);

        float topErosion = fbm2(pos * 1.8 + vec2(time * 0.05, 0.0) + 13.1);
        float topFactor  = smoothstep(0.45, 1.0, h);
        base -= topErosion * 0.35 * topFactor;

        return clamp(base * heightGrad, 0.0, 1.0);
    }

    // Include guard to prevent redefinition errors with volumetricClouds.glsl
    #ifndef HENYEY_GREENSTEIN_DEFINED
    #define HENYEY_GREENSTEIN_DEFINED
    float henyeyGreenstein(float cosAngle, float g) {
        float g2 = g * g;
        return (1.0 - g2) / (4.0 * 3.14159 * pow(1.0 + g2 - 2.0 * g * cosAngle, 1.5));
    }
    float cloudPhaseFunction(float cosAngle, float g) {
        return henyeyGreenstein(cosAngle, g) * 1.5; // Kept for compatibility
    }
    #endif

    // Sky clouds render — Reworked with Fully Dynamic PBR Volumetric Lighting
    vec3 getSkyClouds(in vec3 nEyePlayerPos, in vec3 currSkyCol){
        float cloudHeightFade = nEyePlayerPos.y - 0.05;
        #ifdef FORCE_DISABLE_WEATHER
            cloudHeightFade *= 6.0;
        #else
            cloudHeightFade -= rainStrength * 0.18;
            cloudHeightFade *= 5.6 - rainStrength * 4.5;
        #endif
        if(cloudHeightFade <= 0.0) return currSkyCol;
        cloudHeightFade = clamp(cloudHeightFade, 0.0, 1.0);

        vec3 sunDir = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
        #ifndef FORCE_DISABLE_DAY_CYCLE
            if(dayCycle < 1.0) sunDir = -sunDir;
        #endif
        float sunHeight    = max(0.01, sunDir.y);
        float lowSunFactor = clamp(1.0 - sunHeight * 1.4, 0.0, 1.0);

        float time       = fragmentFrameTime * 0.18;
        vec2 windOffset  = vec2(fragmentFrameTime * 0.055, fragmentFrameTime * 0.0035);

        const float CLOUD_SCALE   = 5.8;
        const float LAYER_STEPS   = 4.0;
        const float LAYER_STEP_H  = 1.0 / LAYER_STEPS;

        // ── FIX: CURVED PROJECTION TO PREVENT HORIZON ACCELERATION ───────────
        // Adding 0.2 to the Y-axis prevents the division from approaching infinity 
        // when looking at the horizon (sunset/sunrise), which caused the clouds to accelerate.
        float viewY = max(0.0, nEyePlayerPos.y) + 0.2; 
        vec2 baseUv = nEyePlayerPos.xz * (CLOUD_SCALE / viewY);

        float totalDensity    = 0.0;
        float topDensity      = 0.0;
        float bottomDensity   = 0.0;
        float depthWeight     = 0.0;

        vec2 parallaxDir = nEyePlayerPos.xz / viewY;

        for(float li = 0.0; li < LAYER_STEPS; li += 1.0) {
            float h        = (li + 0.5) * LAYER_STEP_H;
            float parallax = (h - 0.5) * 0.55;
            vec2 layerUv   = baseUv + windOffset + parallaxDir * parallax;

            float d = cumulusDensity(layerUv, h, time);

            #ifndef FORCE_DISABLE_WEATHER
                d = clamp(d + rainStrength * 0.55, 0.0, 1.0);
            #endif

            totalDensity  += d * LAYER_STEP_H;
            topDensity    += d * h * LAYER_STEP_H;
            bottomDensity += d * (1.0 - h) * LAYER_STEP_H;
            depthWeight   += LAYER_STEP_H;
        }
        float density       = clamp(totalDensity,    0.0, 1.0);
        float topWeight     = depthWeight > 0.001 ? clamp(topDensity    / (density + 0.001), 0.0, 1.0) : 0.5;
        float bottomWeight  = depthWeight > 0.001 ? clamp(bottomDensity / (density + 0.001), 0.0, 1.0) : 0.5;

        if(density < 0.01) return currSkyCol;

        density = clamp(density * CLOUD_FILL, 0.0, 1.0);

        vec3 horizSunDir    = normalize(vec3(sunDir.x, 0.02, sunDir.z));
        vec3 atmosHorizSun  = clamp(seusAtmosphere(horizSunDir,  sunDir), vec3(0.0), vec3(8.0));
        vec3 atmosUp        = clamp(seusAtmosphere(vec3(0.0, 1.0, 0.0), sunDir), vec3(0.0), vec3(6.0));
        vec3 atmosHorizAnti = clamp(seusAtmosphere(-horizSunDir, sunDir), vec3(0.0), vec3(4.0));
        
        // DYNAMIC ATMOS DOWN: Shifts from dark blue to bright sunset orange dynamically
        vec3 atmosDown      = mix(atmosHorizAnti, atmosHorizSun, lowSunFactor);

        float sunViewDot    = clamp(dot(normalize(nEyePlayerPos), sunDir), 0.0, 1.0);
        float sunProximity  = (sunViewDot * sunViewDot * sunViewDot);
        float sunGlowFactor = (sunViewDot * sunViewDot) * dayCycle;
        float antiSunFactor = clamp(1.0 - sunViewDot, 0.0, 1.0);

        vec3 atmosViewDir   = mix(atmosUp, atmosHorizSun, sunGlowFactor * 0.65);
        float antiSqrd = antiSunFactor * antiSunFactor;
        vec3 atmosAmbient   = mix(atmosViewDir, atmosHorizAnti * 0.7, antiSqrd * antiSunFactor * 0.4);

        #ifdef FORCE_DISABLE_DAY_CYCLE
            vec3 directSunColor = lightCol * 2.2;
            vec3 moonLightCol   = lightCol;
        #else
            vec3 moonLightCol   = moonCol;
            vec3 directSunColor = mix(moonLightCol * 0.8,
                                      mix(sunCol * 2.5, atmosHorizSun * 1.5,
                                          lowSunFactor * 0.7 + sunProximity * 0.2),
                                      dayCycleAdjust);
        #endif
        directSunColor = mix(directSunColor, directSunColor * vec3(1.35, 0.95, 0.6), lowSunFactor * 0.5);
        float nightDim = mix(0.08, 1.0, dayCycle);

        // ── FULLY DYNAMIC PBR SELF-SHADOWING (BEER-POWDER) ───────────────────
        vec2 sunXZDir     = sunDir.xz;
        float sunXZLen    = max(length(sunXZDir), 0.001);
        
        // FIX: Use a fixed, reasonable UV shift distance to prevent fast-moving shadows at sunset
        vec2 sunShiftDir  = (sunXZDir / sunXZLen) * 0.15;
        
        float ds = 0.0;
        for (int s = 0; s < 4; ++s) {
            // March a small, fixed distance in UV space
            vec3 sp = vec3(baseUv + windOffset + sunShiftDir * float(s + 1), 0.0);
            float sh = clamp(0.5 + sunHeight * float(s + 1) * 0.05, 0.0, 1.0);
            ds += cumulusDensity(sp.xy, sh, time) * 0.1;
        }
        ds += density * 0.5; 

        float beer = exp(-ds * 3.0); 
        float powder = 1.0 - exp(-ds * 0.5);
        float lightEnergy = beer * 0.85 + powder * 0.15;

        // ── DUAL-LOBE HENYEY-GREENSTEIN PHASE ──────────────────────────────
        float cosAngle = clamp(dot(nEyePlayerPos, sunDir), -1.0, 1.0);
        float phaseForward = henyeyGreenstein(cosAngle, 0.8);
        float phaseBackward = henyeyGreenstein(cosAngle, -0.2);
        float phase = mix(phaseForward, phaseBackward, 0.5);

        // ── SILVER LINING ──────────────────────────────────────────────────
        float silverLining = pow(sunViewDot, 4.0) * (1.0 - beer) * smoothstep(0.0, 0.4, sunHeight);

        // ── AMBIENT OCCLUSION (AO) ─────────────────────────────────────────
        float ambientAO = exp(-ds * 0.5);

        // ── FULLY DYNAMIC SKY SCATTERED AMBIENT ──────────────────────────────
        // Top is lit by zenith sky (bright blue at noon, orange at sunset)
        // Bottom is lit by anti-sun sky (dark blue at noon, twilight purple at sunset)
        // This dynamically shifts as the sun moves!
        vec3 ambientSky = mix(atmosHorizAnti, atmosUp, 0.5); // 0.5 represents average height in 2D slab
        ambientSky = mix(ambientSky, atmosAmbient, 0.5); 
        
        vec3 ambient = ambientSky * 0.8;
        ambient *= ambientAO;
        ambient += silverLining * atmosHorizSun * 0.5;

        vec3 nightAmbient = vec3(0.015, 0.025, 0.04) * (1.0 - dayCycle);
        ambient += nightAmbient;

        // ── DIRECT SUN/MOON LIGHTING (Fully Dynamic) ──────────────────────
        vec3 sunLit = directSunColor * lightEnergy * (0.8 + 1.5 * phase);
        sunLit += directSunColor * silverLining * 2.0;

        // ── FINAL ADDITIVE BLEND ───────────────────────────────────────────
        vec3 directCloud = ambient + sunLit;

        float edgeNoise = fbm2(baseUv * 0.28 + windOffset * 0.4) * 0.22 + 0.78;
        float clouds    = density * cloudHeightFade * 2.0 * edgeNoise;

        vec3 cloudCol = directCloud * clouds;

        float viewFactor     = 1.0 - max(clamp(nEyePlayerPos.y, 0.0, 1.0), 0.0);
        float underCloudDark = clamp(pow(density, 1.0) * 0.65 * cloudHeightFade
                                     * (0.40 + viewFactor * 1.3), 0.0, 0.95);
        currSkyCol *= (1.0 - underCloudDark);

        return currSkyCol + cloudCol * density;
    }

#endif


mat2 mm2(in float a){float c = cos(a), s = sin(a);return mat2(c,s,-s,c);}
mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);
float tri(in float x){return clamp(abs(fract(x)-.5),0.01,0.49);}
vec2 tri2(in vec2 p){return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

float triNoise2d(in vec2 p, float spd)
{
    float z=1.8;
    float z2=2.5;
    float rz = 0.;
    p *= mm2(p.x*0.06);
    vec2 bp = p;
    for (float i=0.; i<5.; i++ )
    {
        vec2 dg = tri2(bp*1.85)*.75;
        dg *= mm2(time*spd);
        p -= dg/z2;

        bp *= 1.3;
        z2 *= .45;
        z *= .42;
        p *= 1.21 + (rz-1.0)*.02;
        
        rz += tri(p.x+tri(p.y))*z;
        p*= -m2;
    }
    return clamp(1./pow(rz*29., 1.3),0.,.55);
}

float auroraHash21(in vec2 n){ return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453); }
vec4 aurora(vec3 ro, vec3 rd)
{
    vec4 col = vec4(0);
    vec4 avgCol = vec4(0);

    for(float i=0.;i<25.;i++)
    {
        float of = 0.0;
        float pt = ((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
        pt -= of;
        vec3 bpos = ro + pt*rd;
        vec2 p = bpos.zx;
        float rzt = triNoise2d(p, 0.06);
        vec4 col2 = vec4(0,0,0, rzt);
        col2.rgb = (sin(1.-vec3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;
        avgCol =  mix(avgCol, col2, .5);
        col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);

    }

    return col*0.5;
}

vec4 singularity(vec2 F, float iTime)
{
    float i = .2, a;
    vec2 r = vec2(400,300),
         p = ( F+F - r ) / r.y / .7,
         d = vec2(-1,1),
         b = p - i*d,
         c = p * mat2(1, 1, d/(.1 + i/dot(b,b))),
         v = c * mat2(cos(.5*log(a=dot(c,c)) + iTime*i + vec4(0,33,11,0)))/i,
         w;
    
    for(; i++<9.; w += 1.+sin(v) )
        v += .7* sin(v.yx*i+iTime) / i + .5;
    i = length( sin(v/.3)*.4 + c*(3.+d) );
    return 1. - exp( -exp( c.x * vec4(.6,-.4,-1,0) )
                   /  w.xyyx
                   / ( 2. + i*i/4. - i )
                   / ( .5 + 1. / a )
                   / ( .03 + abs( length(p)-.7 ) )
             );
}

// ============================================================================
// REWORKED SHOOTING STAR (Curved Bezier Path & Glowing Trail)
// ============================================================================
vec3 getShootingStar(vec2 uv, float time, float progress) {
    // Define a curved flight path using a quadratic Bezier curve
    vec2 startPos = vec2(-0.1, 0.75);
    vec2 endPos = vec2(1.1, 0.35);
    vec2 ctrlPos = vec2(0.5, 0.55); // Control point for the curve
    
    // Calculate current position along the curve
    vec2 p0 = mix(startPos, ctrlPos, progress);
    vec2 p1 = mix(ctrlPos, endPos, progress);
    vec2 currentPos = mix(p0, p1, progress);
    
    // Calculate the tangent (direction) at the current point for the trail
    vec2 dir = normalize(p1 - p0);
    
    // Vector from the star's current position to the screen pixel
    vec2 toPixel = uv - currentPos;
    
    // Project the vector onto the direction to find out how far along the path the pixel is
    float along = dot(toPixel, dir);
    
    // Calculate perpendicular distance from the path line
    float perp = abs(toPixel.x * dir.y - toPixel.y * dir.x);
    
    // 1. Bright glowing head (Tightened significantly for a smaller size)
    float headDist = length(toPixel);
    float headGlow = exp(-headDist * 400.0) * 1.5;
    
    // 2. Fading trail (Shortened and tightened)
    float trail = 0.0;
    // Trail only exists behind the head (along < 0)
    if (along < 0.0) {
        float trailLen = 0.1; // Shorter trail
        // Fade out towards the tail
        float trailFade = smoothstep(trailLen, 0.0, -along);
        
        // Very tight Gaussian for the line thickness (thinner line)
        float thickness = 0.0008;
        float lineFade = exp(-perp * 1000.0);
        
        // Add a subtle twinkle/shimmer to the trail
        float shimmer = sin(time * 40.0 + along * 80.0) * 0.2 + 0.8;
        
        trail = trailFade * lineFade * shimmer;
    }
    
    // Color: Bright white-yellow at the head, fading to cyan/blue in the trail
    vec3 headColor = vec3(1.0, 0.95, 0.8);
    vec3 trailColor = vec3(0.4, 0.7, 1.0);
    
    vec3 col = headColor * headGlow + trailColor * trail;
    
    // Fade the whole star in and out at the start and end of its flight
    float alpha = smoothstep(0.0, 0.1, progress) * smoothstep(1.0, 0.9, progress);
    
    return col * alpha;
}

// ============================================================================
// Atmospheric scattering — Physical Rayleigh-Mie Model 
// Based on GPU Gems 2, Scratchapixel, and Unreal Engine Sky Atmosphere
// ============================================================================

#define PI  3.14159265359
#define TAU 6.28318530718

// Planet and Atmosphere geometry (in meters)
#define PLANET_RADIUS 6360e3
#define ATMOS_RADIUS  6420e3

// Scale heights (meters)
#define RAYLEIGH_H    8000.0
#define MIE_H         1200.0

// Scattering coefficients (1/meters)
#define RAYLEIGH_BETA vec3(5.8e-6, 13.5e-6, 33.1e-6)
#define MIE_BETA      vec3(21e-6)

// Sun intensity and Mie asymmetry
#define SUN_INTENSITY  22.0
#define G_MIE          0.758

// Ray-sphere intersection (returns vec2(t_near, t_far))
vec2 raySphere(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if (h < 0.0) return vec2(-1.0);
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

// Physical atmospheric scattering integrator
vec3 physicalAtmosphere(vec3 rayDir, vec3 sunDir) {
    // Player position relative to planet center (1.0m above surface for stability)
    vec3 eyePos = vec3(0.0, PLANET_RADIUS + 1.0, 0.0);
    vec3 dir = rayDir;
    // Clamp to 0.05 to prevent infinite ray length and black lines exactly at y=0
    dir.y = max(dir.y, 0.05); 

    // We are inside the sphere, so we need the far intersection (.y)
    float tAtmos = raySphere(eyePos, dir, ATMOS_RADIUS).y;
    if (tAtmos < 0.0) return vec3(0.0);

    int steps = 16;
    float stepSize = tAtmos / float(steps);
    vec3 p = eyePos + dir * (stepSize * 0.5);

    vec3 totalR = vec3(0.0);
    vec3 totalM = vec3(0.0);
    float opticalR = 0.0;
    float opticalM = 0.0;

    // Phase functions
    float mu = dot(dir, sunDir);
    float phaseR = 0.0596831 * (1.0 + mu * mu);
    float g = G_MIE;
    float phaseM = 0.1193662 * ((1.0 - g * g) * (mu * mu + 1.0)) / pow(1.0 + g * g - 2.0 * g * mu, 1.5);

    for (int i = 0; i < 4; ++i) {
        float height = length(p) - PLANET_RADIUS;
        if (height < 0.0) break; // Inside planet

        float hr = exp(-height / RAYLEIGH_H) * stepSize;
        float hm = exp(-height / MIE_H) * stepSize;
        opticalR += hr;
        opticalM += hm;

        // Light ray march toward sun
        float tLight = raySphere(p, sunDir, ATMOS_RADIUS).y;
        float tPlanet = raySphere(p, sunDir, PLANET_RADIUS).x;
        
        // If the light ray hits the planet, we are in planetary shadow (night)
        if (tPlanet < 0.0) {
            if (tLight < 0.0) tLight = 0.0;

            float lightStep = tLight / 4.0;
            vec3 lp = p + sunDir * (lightStep * 0.5);
            float lOpticalR = 0.0;
            float lOpticalM = 0.0;
            
            for (int j = 0; j < 4; ++j) {
                float lHeight = length(lp) - PLANET_RADIUS;
                if (lHeight > 0.0) {
                    lOpticalR += exp(-lHeight / RAYLEIGH_H) * lightStep;
                    lOpticalM += exp(-lHeight / MIE_H) * lightStep;
                }
                lp += sunDir * lightStep;
            }

            vec3 tau = RAYLEIGH_BETA * (opticalR + lOpticalR) + MIE_BETA * (opticalM + lOpticalM) * 1.1;
            vec3 attenuation = exp(-tau);

            totalR += hr * attenuation;
            totalM += hm * attenuation;
        }
        p += dir * stepSize;
    }

    // Simple multi-scattering approximation to prevent night sky from being pitch black
    vec3 ms = 0.1 * RAYLEIGH_BETA * phaseR * SUN_INTENSITY;
    return SUN_INTENSITY * (totalR * RAYLEIGH_BETA * phaseR + totalM * MIE_BETA * phaseM) + ms;
}

// Wrapper for legacy calls
vec3 seusAtmosphere(vec3 rayDir, vec3 lightDir) {
    return physicalAtmosphere(rayDir, lightDir);
}

void scatter(vec3 o, vec3 d, vec3 lightsource, out vec3 raleigh, out vec3 themie, out float depthM){
    vec3 total = physicalAtmosphere(d, lightsource);
    raleigh = total * 0.6;
    themie  = total * 0.4;
    depthM  = 0.0;
}

//-------------------Background and Stars--------------------

vec3 nmzHash33(vec3 q)
{
    uvec3 p = uvec3(ivec3(q));
    p = p*uvec3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
    p = p.yzx*(p.zxy^(p >> 3U));
    return vec3(p^(p >> 16U))*(1.0/vec3(0xffffffffU));
}

vec3 stars(in vec3 p)
{
    vec3 c = vec3(0.0);
    vec3 pp = p * 64.0;
    for(int i = 0; i < 4; ++i) {
        vec3 id = floor(pp);
        vec3 q = fract(pp) - 0.5;
        vec2 rn = nmzHash33(id).xy;
        float d = length(q);
        float c2 = 1.0 - smoothstep(0.0, 0.6, d);
        float thresh = 0.999 - float(i) * 0.0008 - rn.x * 0.0025;
        if (rn.x > thresh) {
            vec3 starCol = mix(vec3(1.0,0.49,0.1), vec3(0.75,0.9,1.0), rn.y) * (0.1) + vec3(0.9);
            c += c2 * starCol;
        }
        pp *= 1.3;
    }
    return c * c * 0.8;
}

vec3 getSkyBasic(in vec3 nEyePlayerPos, in vec3 skyPos, in bool isSkyFragment){


    // Fallback deep blue night sky so the horizon never goes pitch black
    vec3 currSkyCol = max(skyCol * dayCycleAdjust, vec3(0.005, 0.008, 0.015));

    #if defined WORLD_LIGHT && WORLD_SUN_MOON == 1
        vec3 camDir = normalize(nEyePlayerPos);

        vec3 sunDirScatter = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
        #ifndef FORCE_DISABLE_DAY_CYCLE
            if(dayCycle < 1.0) sunDirScatter = -sunDirScatter;
        #endif
        float sunElev = sunDirScatter.y;

        // ── Physical Atmospheric Scattering ──────────────────────────────────
        vec3 atmosphere = physicalAtmosphere(camDir, sunDirScatter);

        // Moon pass: anti-sun direction, active only at night
        #ifndef FORCE_DISABLE_DAY_CYCLE
            float nightDepth = clamp(1.0 - dayCycle, 0.0, 1.0);
            // Increased multiplier from 0.00025 to 0.5 so the moon physically scatters light
            atmosphere += physicalAtmosphere(camDir, -sunDirScatter) * nightDepth * 0.5;
        #endif

        atmosphere = clamp(atmosphere, vec3(0.0), vec3(16.0));

        if(isSkyFragment) {
            // Use the highest light source (sun or moon) to determine sky visibility
            float moonElev = -sunElev;
            float lightElev = max(sunElev, moonElev);
            float scatterBlend = clamp(lightElev * 4.0 + 1.0, 0.0, 1.0);
            
            // Blend daytime and nighttime physical atmosphere based on dayCycle
            #ifndef FORCE_DISABLE_DAY_CYCLE
                float dayMix = clamp(dayCycle * 2.0, 0.0, 1.0);
                currSkyCol = mix(currSkyCol * (1.0 - dayMix), atmosphere, scatterBlend * (dayMix + (1.0 - dayMix) * 0.5));
            #else
                currSkyCol = mix(currSkyCol, atmosphere, scatterBlend);
            #endif
            

            // ── Sunset/sunrise limb saturation boost ─────────────────────────
            if (sunElev < 0.2) {
                float lowSunFact = clamp(1.0 - abs(sunElev) * 4.0, 0.0, 1.0)
                                 * clamp(sunElev + 0.3, 0.0, 1.0); // only sun side
                float horizBand  = clamp(1.0 - abs(camDir.y) * 5.5, 0.0, 1.0);
                vec3 limbTint    = mix(vec3(1.0), clamp(sunCol * 1.5, 0.0, 4.0), 0.2);
                currSkyCol      += currSkyCol * horizBand * lowSunFact * (limbTint - 1.0) * 50.25;
            }
            
            // ── Daytime Horizon Glow Boost ──────────────────────────────────
            // Adds a warm, bright atmospheric haze to the horizon during the day
            else if (sunElev >= 0.2) {
                // Fade this glow in as the sun rises, and out as it gets very high
                float dayHorizFact = smoothstep(0.2, 0.5, sunElev) * (1.0 - smoothstep(0.8, 1.0, sunElev));
                float horizBand    = clamp(1.0 - abs(camDir.y) * 4.0, 0.0, 1.0);
                
                // Shift the horizon color towards warm yellow/white
                vec3 dayGlowTint  = mix(vec3(1.0), normalize(sunCol + vec3(0.001)), 1.0);
                currSkyCol         = mix(currSkyCol, currSkyCol * dayGlowTint, horizBand * dayHorizFact * 1.0);
                
                // Add a subtle brightness boost to the horizon line
                currSkyCol        += vec3(0.02, 0.015, 0.0) * horizBand * dayHorizFact;
            }

            // ── Belt of Venus / twilight arch ─────────────────────────────────
            float twilight = smoothstep(0.12, 0.0, sunElev)
                           * smoothstep(-0.28, -0.05, sunElev)
                           * clamp(1.0 - camDir.y * 3.5, 0.0, 1.0);
            currSkyCol += vec3(0.75, 0.48, 0.72) * 0.22 * twilight;

            // ── Existing diffuse sun/moon tint ────────────────────────────────
            #ifdef FORCE_DISABLE_DAY_CYCLE
                if(skyPos.z > 0.0)
                    currSkyCol += lightCol * pow(skyPos.z * skyPos.z, abs(nEyePlayerPos.y) + 1.0);
            #else
                float lightDiffuse       = pow(skyPos.z * skyPos.z, abs(nEyePlayerPos.y) + 1.0);
                float diffuseCycleAdjust = dayCycleAdjust * lightDiffuse;
                currSkyCol += skyPos.z > 0.0
                    ? sunCol  * diffuseCycleAdjust
                    : moonCol * (lightDiffuse - diffuseCycleAdjust);
            #endif
        }
    #endif

    currSkyCol += lightningFlash;

    // Night stars
    #ifdef WORLD_STARS
    if(sunElev < 0.0) {
        // Fade stars in based on how far below the horizon the sun is
        float nightVis = clamp(-sunElev * 4.0, 0.0, 1.0);
        vec3 starDir = normalize(nEyePlayerPos);
        vec3 starField = stars(starDir);

        float seed = fract(sin(dot(starDir.xz, vec2(12.9898,78.233))) * 43758.5453);
        float tw = 0.5 + 0.5 * sin(fragmentFrameTime * (1.8 + seed * 3.5) + seed * 12.34);
        float twinkleStrength = mix(1.7, 1.6, tw);

        vec3 starCol = clamp(starField * twinkleStrength * nightVis * 1.2, vec3(0.0), vec3(6.0));

        if (isSkyFragment) currSkyCol += starCol * 1.85;
    }
    #endif

    return currSkyCol;
}

vec3 getSkyHalf(in vec3 nEyePlayerPos, in vec3 skyPos, in vec3 currSkyCol){
    #if (defined WORLD_AETHER && defined WORLD_LIGHT) || defined WORLD_STARS
        vec2 skyCoordScale = skyPos.xy * 256.0;
    #endif

    #if defined WORLD_AETHER && defined WORLD_LIGHT
        int aetherAnimationSpeed = int(fragmentFrameTime * 8.0);
        ivec2 aetherTexelCoord0 = ivec2(255 - skyCoordScale - aetherAnimationSpeed) & 255;
        ivec2 aetherTexelCoord1 = ivec2(aetherTexelCoord0.x, int(skyCoordScale.y - aetherAnimationSpeed) & 255);
        ivec2 aetherTexelCoord2 = ivec2(int(skyCoordScale.x - aetherAnimationSpeed) & 255, aetherTexelCoord0.y);
        vec3 aetherNoise = vec3(texelFetch(noisetex, aetherTexelCoord0, 0).z,
            texelFetch(noisetex, aetherTexelCoord1, 0).z,
            texelFetch(noisetex, aetherTexelCoord2, 0).z);
        currSkyCol += exp2(-abs(nEyePlayerPos.y) * 8.0) * cubed(aetherNoise * lightCol + sumOf(aetherNoise) * 0.66666666) * lightCol;
    #endif

    #ifdef WORLD_STARS
        vec2 starData = texelFetch(noisetex, ivec2(skyCoordScale / (abs(skyPos.z) + sqrt(1.0 - skyPos.z * skyPos.z))) & 255, 0).xy;
        float stars = exp(starData.x * starData.y * 64.0 - 64.0);
        #ifdef FORCE_DISABLE_WEATHER
            currSkyCol += stars * WORLD_STARS;
        #else
            currSkyCol += (1.0 - rainStrength) * stars * WORLD_STARS;
        #endif
    #endif

    return currSkyCol;
}

vec3 getSkyFogRender(in vec3 nEyePlayerPos){
    if(isEyeInWater == 1) return UNDERWATER_FOG_COLOR;
    if(isEyeInWater == 2) return fogColor;

    vec3 skyPos = mat3(shadowModelView) * nEyePlayerPos;
    #if defined WORLD_LIGHT && !defined FORCE_DISABLE_DAY_CYCLE
        if(dayCycle < 1) skyPos.xz = -skyPos.xz;
    #endif

    vec3 currSkyCol = getSkyBasic(nEyePlayerPos, skyPos, true);

    #if defined WORLD_AETHER && defined WORLD_LIGHT
        vec2 skyCoordScale = skyPos.xy * 256.0;
        int aetherAnimationSpeed = int(fragmentFrameTime * 8.0);
        ivec2 aetherTexelCoord0 = ivec2(255 - skyCoordScale - aetherAnimationSpeed) & 255;
        ivec2 aetherTexelCoord1 = ivec2(aetherTexelCoord0.x, int(skyCoordScale.y - aetherAnimationSpeed) & 255);
        ivec2 aetherTexelCoord2 = ivec2(int(skyCoordScale.x - aetherAnimationSpeed) & 255, aetherTexelCoord0.y);
        vec3 aetherNoise = vec3(texelFetch(noisetex, aetherTexelCoord0, 0).z,
            texelFetch(noisetex, aetherTexelCoord1, 0).z,
            texelFetch(noisetex, aetherTexelCoord2, 0).z);
        currSkyCol += exp2(-abs(nEyePlayerPos.y) * 8.0) * cubed(aetherNoise * lightCol + sumOf(aetherNoise) * 0.66666666) * lightCol;
    #endif

    float horizonFade = smoothstep(-0.1, 0.05, nEyePlayerPos.y + (eyeBrightFact - 0.33) * 3.0);
    return currSkyCol * horizonFade;
}

vec3 getSkyFogRender(in vec3 nEyePlayerPos, in vec3 skyPos, in vec3 currSkyCol){
    if(isEyeInWater == 1) return UNDERWATER_FOG_COLOR;
    if(isEyeInWater == 2) return fogColor;

    #if defined WORLD_AETHER && defined WORLD_LIGHT
        vec2 skyCoordScale = skyPos.xy * 256.0;
        int aetherAnimationSpeed = int(fragmentFrameTime * 8.0);
        ivec2 aetherTexelCoord0 = ivec2(255 - skyCoordScale - aetherAnimationSpeed) & 255;
        ivec2 aetherTexelCoord1 = ivec2(aetherTexelCoord0.x, int(skyCoordScale.y - aetherAnimationSpeed) & 255);
        ivec2 aetherTexelCoord2 = ivec2(int(skyCoordScale.x - aetherAnimationSpeed) & 255, aetherTexelCoord0.y);
        vec3 aetherNoise = vec3(texelFetch(noisetex, aetherTexelCoord0, 0).z,
            texelFetch(noisetex, aetherTexelCoord1, 0).z,
            texelFetch(noisetex, aetherTexelCoord2, 0).z);
        currSkyCol += exp2(-abs(nEyePlayerPos.y) * 8.0) * cubed(aetherNoise * lightCol + sumOf(aetherNoise) * 0.66666666) * lightCol;
    #endif

    float horizonFade = smoothstep(-0.1, 0.05, nEyePlayerPos.y + (eyeBrightFact - 0.33) * 3.0);
    return currSkyCol * horizonFade;
}

// Sun / Moon shape helpers
float getSunMoonShape(in float z){
    float r = sqrt(max(0.0, 1.0 - z * z));
    const float inner = 0.005;
    const float outer = 0.105;
    return 1.0 - smoothstep(inner, outer, r);
}

float getSunMoonShape(in vec2 xy){
    float r = length(xy);
    const float inner = 0.02;
    const float outer = 0.03;
    return 1.0 - smoothstep(inner, outer, r);
}

// ── PHYSICALLY ACCURATE SUN DISK ─────────────────────────────────────────────
// Renders a sharp sun disk with a smooth atmospheric halo.
// Angular size is precisely tuned to match real-world sun (0.53 degrees).
vec3 renderSunDisk(in vec3 skyPos, in vec3 sunCol) {
    // skyPos.z acts as the dot product (1.0 = looking directly at sun)
    float r = sqrt(max(0.0, 1.0 - skyPos.z * skyPos.z));
    
    // Sharp physical disk
    float diskCore = 1.0 - smoothstep(0.0040, 0.0046, r);
    
    // Soft atmospheric halo (Mie scattering glow)
    float haloFalloff = exp(-(r * r) / 0.0025) * 0.8;
    
    // Combine disk + halo
    float sunIntensity = diskCore * 50.0 + haloFalloff * 2.5;
    
    // Tint sun red/orange when it's low on the horizon (atmospheric extinction)
    float sunElev = max(0.0, skyPos.z);
    vec3 tint = mix(vec3(1.0, 0.4, 0.1), vec3(1.0, 0.95, 0.9), smoothstep(0.0, 0.3, sunElev));
    
    return sunCol * sunIntensity * tint;
}

// ── PHYSICALLY ACCURATE MOON DISK ────────────────────────────────────────────
// Renders a bright moon disk with a soft glow.
vec3 renderMoonDisk(in vec3 skyPos, in vec3 moonCol) {
    float r = sqrt(max(0.0, 1.0 - skyPos.z * skyPos.z));
    
    // Sharp physical disk
    float diskCore = 1.0 - smoothstep(0.0038, 0.0045, r);
    
    // Soft halo
    float haloFalloff = exp(-(r * r) / 0.004) * 0.4;
    
    float moonIntensity = diskCore * 15.0 + haloFalloff * 1.5;
    
    return moonCol * moonIntensity;
}

vec3 getSkyReflection(in vec3 reflectViewDir){
    if(isEyeInWater == 2) return fogColor;

    vec3 reflectPlayerDir = mat3(gbufferModelViewInverse) * reflectViewDir;
    vec3 skyPos = mat3(shadowModelView) * reflectPlayerDir;

    #if defined WORLD_LIGHT && !defined FORCE_DISABLE_DAY_CYCLE
        if(dayCycle < 1) skyPos.xz = -skyPos.xz;
    #endif

    vec3 currSkyCol = getSkyBasic(reflectPlayerDir, skyPos, true);

    #ifdef WORLD_LIGHT
        #if WORLD_SUN_MOON == 1 && SUN_MOON_TYPE != 2
            #if SUN_MOON_TYPE == 1
                float r = sqrt(max(0.0, 1.0 - skyPos.z * skyPos.z));
                const float inner = 0.005;
                const float outer = 0.105;
                float sunMoonShape = (1.0 - smoothstep(inner, outer, r)) * sunMoonIntensitySqrd;
            #else
                float r = length(skyPos.xy);
                const float inner = 0.005;
                const float outer = 0.105;
                float sunMoonShape = (1.0 - smoothstep(inner, outer, r)) * sunMoonIntensitySqrd;
            #endif

            #ifndef FORCE_DISABLE_WEATHER
                #ifdef FORCE_DISABLE_DAY_CYCLE
                    currSkyCol += sRGBLightCol * (sunMoonShape - rainStrength * sunMoonShape) * 4.0;
                #else
                    if(skyPos.z > 0) {
                        currSkyCol += sRGBSunCol * (sunMoonShape - rainStrength * sunMoonShape) * 4.0;
                    } else {
                        currSkyCol += sRGBMoonCol * (sunMoonShape - rainStrength * sunMoonShape) * 0.5;
                    }
                #endif
            #endif
        #elif WORLD_SUN_MOON == 2
            float blackHole = sqrt(1.0 - skyPos.z * skyPos.z) - WORLD_SUN_MOON_SIZE;
            if(blackHole <= 0) return vec3(0);
            blackHole = 1.0 / max(1.0, blackHole * 256.0);
            const float rotationFactor = TAU * 16.0;
            skyPos.xy = rot2D(blackHole * rotationFactor) * skyPos.xy;
            float rings = textureLod(noisetex, vec2(skyPos.x * blackHole, fragmentFrameTime * 0.0009765625), 0).x;
            currSkyCol += ((rings * blackHole * 0.9 + blackHole * 0.1) * sunMoonIntensitySqrd) * lightCol;
        #endif
    #endif

    vec3 finalCol = getSkyHalf(reflectPlayerDir, skyPos, currSkyCol);

    #if !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
        finalCol = getSkyClouds(reflectPlayerDir, finalCol);

        // FIX: Add volumetric clouds to reflections when volumetric clouds
        // are enabled. We perform a compact raymarch of the volumetric cloud
        // layer along the reflected direction and blend the resulting color
        // using the returned alpha (opacity).
        #if CLOUD_TYPE == 2
            // small pseudo-random dither to decorrelate marching patterns
            float reflDither = fract(sin(dot(gl_FragCoord.xy ,vec2(12.9898,78.233))) * 43758.5453);
            vec3 nRefDir = normalize(reflectPlayerDir);
            // approximate cloud origin used elsewhere in composite pass
            vec3 cloudStartPos = vec3(cameraPosition.x + fragmentFrameTime, cameraPosition.y - 1536.0, cameraPosition.z);
            vec4 volCloud = volumetricClouds(nRefDir, cloudStartPos, borderFar, reflDither, true);
            // blend volumetric cloud contribution into the reflected sky
            finalCol = mix(finalCol, volCloud.rgb, clamp(volCloud.a, 0.0, 1.0) * 0.85);
        #endif
    #endif

    if(isEyeInWater == 1) return finalCol * max(0.0, reflectPlayerDir.y + eyeBrightFact - 1.0);

    #ifdef WORLD_LIGHT
        const float fakeVLBrightness = VOLUMETRIC_LIGHTING_STRENGTH * 0.5;
        float VLBrightness = fakeVLBrightness * shdFade;

        if(reflectPlayerDir.y > 0){
            float heightFade = squared(squared(squared(1.0 - squared(reflectPlayerDir.y))));
            #ifndef FORCE_DISABLE_WEATHER
                heightFade += (1.0 - heightFade) * rainStrength * 0.5;
            #endif
            VLBrightness *= heightFade;
        }
        finalCol += lightCol * VLBrightness;
    #endif

    return finalCol * smoothstep(0.0, 0.1, reflectPlayerDir.y + eyeBrightFact * 3.0 - 1.0);
}

// Full sky render
vec3 getFullSkyRender(in vec3 nEyePlayerPos, in vec3 skyPos, in vec3 currSkyCol){
    if(isEyeInWater == 2) return fogColor;

    currSkyCol = getSkyBasic(nEyePlayerPos, skyPos, true);

    #ifdef WORLD_LIGHT
        #if WORLD_SUN_MOON == 1 && SUN_MOON_TYPE != 2
            #ifndef FORCE_DISABLE_WEATHER
                #ifdef FORCE_DISABLE_DAY_CYCLE
                    vec3 lightContribution = renderSunDisk(skyPos, sRGBLightCol);
                    currSkyCol += lightContribution * (1.0 - rainStrength);
                #else
                    if(skyPos.z > 0.0) {
                        vec3 sunContribution = renderSunDisk(skyPos, sRGBSunCol) * dayCycleAdjust;
                        currSkyCol += sunContribution * (1.0 - rainStrength * 0.5);
                    } else {
                        vec3 moonContribution = renderMoonDisk(skyPos, sRGBMoonCol) * (1.0 - dayCycleAdjust);
                        currSkyCol += moonContribution * (1.0 - rainStrength * 0.3);
                    }
                #endif
            #endif
        #elif WORLD_SUN_MOON == 2
            float blackHole = sqrt(1.0 - skyPos.z * skyPos.z) - WORLD_SUN_MOON_SIZE;
            if(blackHole <= 0) return vec3(0);
            blackHole = 1.0 / max(1.0, blackHole * 256.0);
            const float rotationFactor = TAU * 16.0;
            skyPos.xy = rot2D(blackHole * rotationFactor) * skyPos.xy;
            float rings = textureLod(noisetex, vec2(skyPos.x * blackHole, fragmentFrameTime * 0.0009765625), 0).x;
            currSkyCol += ((rings * blackHole * 0.9 + blackHole * 0.1) * sunMoonIntensitySqrd) * lightCol;
        #endif
    #endif

    // Combine sky box color and sky half color
    currSkyCol = getSkyHalf(nEyePlayerPos, skyPos, currSkyCol);

    // Only render 2D skybox clouds if volumetric clouds (CLOUD_TYPE == 2) are disabled
    #if CLOUD_TYPE == 1 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
        currSkyCol = getSkyClouds(nEyePlayerPos, currSkyCol);
    #endif

    // Add Singularity blackhole effect only at night
    if(dayCycle < 1.0 && nEyePlayerPos.y > 0.0){
        vec2 uv = vec2(0.0, 0.5);
        vec2 F = uv * vec2(800, 600);
        vec4 sing = singularity(F, fragmentFrameTime);
        float fadeFactor = 1.0 - dayCycle;
        currSkyCol += sing.rgb * 1.0 * fadeFactor;
    }

    // Add shooting star effect
    {
        // Calculate sun elevation to check if it is night
        vec3 sunDirCheck = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
        #ifndef FORCE_DISABLE_DAY_CYCLE
            if(dayCycle < 1.0) sunDirCheck = -sunDirCheck;
        #endif
        
        // Only show shooting stars at night
        if(sunDirCheck.y < 0.0) {
            float cycleTime = 15.0;
            float duration = 1.5;
            float t = fract(fragmentFrameTime / cycleTime) * cycleTime;
            
            // Main shooting star
            if(t < duration){
                float progress = t / duration;
                vec2 skyUV = vec2(skyPos.x * 0.5 + 0.5, skyPos.y * 0.5 + 0.5);
                currSkyCol += getShootingStar(skyUV, fragmentFrameTime, progress) * 1.5;
            }
            
            // Second, offset shooting star
            float t2 = fract((fragmentFrameTime + cycleTime * 0.5) / cycleTime) * cycleTime;
            if(t2 < duration * 0.8) {
                float progress2 = t2 / (duration * 0.8);
                vec2 skyUV2 = vec2(skyPos.x * 0.5 + 0.5, (skyPos.y + 0.1) * 0.5 + 0.5);
                currSkyCol += getShootingStar(skyUV2, fragmentFrameTime, progress2) * 1.0;
            }
        }
    }

    // Shifted fade down (-0.1 to 0.05) so y=0 is always fully visible, preventing black horizon line
    if(isEyeInWater == 1) return currSkyCol * smoothstep(-0.1, 0.05, nEyePlayerPos.y * 1.66666667 - 0.16666667);
    return currSkyCol * smoothstep(-0.1, 0.05, nEyePlayerPos.y + (eyeBrightFact - 0.33) * 3.0);
}

#endif