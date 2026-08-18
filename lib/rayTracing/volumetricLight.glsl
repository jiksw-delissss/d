#define VOLUMETRIC_LIGHT_STEPS 7u

const float volumetricStepsInverse = 1.0 / VOLUMETRIC_LIGHT_STEPS;

#include "/lib/surface/water.glsl"


// Texture-based caustic function - HARCODED for 4096
// Strip line caustic function - HARCODED for 4096 with linear patterns
float getWaveCaustic(in vec2 worldPosXZ, in float animateTime) {
    // COMPLETELY HARCODED for 4096 - creates strip line patterns
    const float STRIPE_SCALE = 0.025; // 1/40 - controls stripe density
    const float STRIPE_WIDTH = 0.4; // Width of each stripe (0-1)
    const float STRIPE_SPACING = 2.0; // Space between stripes
    
    // Create directional stripes (angled for more natural look)
    vec2 dir = vec2(0.866, 0.5); // 30 degree angle vector
    float stripePos = dot(worldPosXZ * STRIPE_SCALE, dir);
    
    // Add animation movement
    stripePos += animateTime * 0.04;
    
    // Create strip lines using sine waves
    float stripes = sin(stripePos * STRIPE_SPACING * 3.14159);
    
    // Make stripes sharp and well-defined
    float stripeIntensity = abs(stripes);
    stripeIntensity = smoothstep(STRIPE_WIDTH, 0.0, stripeIntensity);
    
    // Add secondary perpendicular stripes for grid/crosshatch effect
    vec2 dir2 = vec2(-0.5, 0.866); // Perpendicular 120 degree angle
    float stripePos2 = dot(worldPosXZ * STRIPE_SCALE * 0.7, dir2);
    stripePos2 += animateTime * 0.03;
    
    float stripes2 = sin(stripePos2 * STRIPE_SPACING * 1.8 * 3.14159);
    float stripeIntensity2 = abs(stripes2);
    stripeIntensity2 = smoothstep(STRIPE_WIDTH * 1.2, 0.0, stripeIntensity2);
    
    // Combine both stripe directions
    float combinedStripes = max(stripeIntensity, stripeIntensity2 * 0.6);
    
    // Add some wave-like variation to the stripes
    float waveVar = sin(stripePos * 0.5 + animateTime * 0.8) * 0.3 + 0.7;
    combinedStripes *= waveVar;
    
    // Add subtle noise texture for organic feel
    vec2 noiseUv = worldPosXZ * STRIPE_SCALE * 0.3;
    float noise = textureLod(noisetex, noiseUv + vec2(animateTime * 0.01), 1.0).r;
    noise = noise * 0.3 + 0.7; // Reduce contrast
    
    // Modulate stripes with noise
    combinedStripes *= noise;
    
    // Create bright highlights on stripes
    combinedStripes = pow(combinedStripes, 1.5);
    
    // Add pulsing effect
    float pulse = sin(animateTime * 2.0) * 0.2 + 0.8;
    combinedStripes *= pulse;
    
    // Boost intensity for 4096 clarity
    return saturate(combinedStripes * 1.5);
}

vec3 getVolumetricLight(in vec3 nFeetPlayerPos, in float feetPlayerDist, in float fogFactor, in float borderFog, in float dither, in bool isSky){
    float bloomMult = 1.0;
    #ifdef BLOOM
        bloomMult = 2.0;
    #endif

    float totalFogDensity = FOG_TOTAL_DENSITY;

    #ifdef FORCE_DISABLE_WEATHER
        if(isEyeInWater != 0) totalFogDensity *= TAU;
    #else
        totalFogDensity *= isEyeInWater == 0 ? (rainStrength * PI + 1.0) : TAU;
    #endif

    float heightFade = 1.0;

    // Fade VL, but do not apply to underwater VL
    if(isEyeInWater == 0 && nFeetPlayerPos.y > 0){
        heightFade = squared(squared(1.0 - squared(nFeetPlayerPos.y)));
        if(isSky) heightFade *= heightFade;

        #ifndef WORLD_CUSTOM_SKYLIGHT
            #ifndef FORCE_DISABLE_WEATHER
                heightFade += (1.0 - heightFade) * max(1.0 - eyeBrightFact, rainStrength * 0.5);
            #else
                heightFade += (1.0 - heightFade) * (1.0 - eyeBrightFact);
            #endif
        #endif
    }

    float volumetricFogDensity = 1.0 - exp2(-feetPlayerDist * totalFogDensity);
    volumetricFogDensity = (volumetricFogDensity - fogFactor) * VOLUMETRIC_LIGHTING_STRENGTH + fogFactor;

    // Border fog
    #ifdef BORDER_FOG
        volumetricFogDensity = (volumetricFogDensity - 1.0) * borderFog + 1.0;
    #endif

    // Calculate underwater boost factor - only apply when underwater
    float underwaterBoost = 1.0;
    if(isEyeInWater == 1) {
        // Boost volumetric light strength when underwater
        underwaterBoost = UNDERWATER_VOLUMETRIC_BOOST;
        
        // Also increase fog density underwater for stronger effect
        volumetricFogDensity *= 1.5; // Additional underwater density boost
    }

    // ── SKY ONLY CLOUD CREPUSCULAR RAYS ──────────────────────────────────────
    // Traces light shafts from the 2048-high clouds, fading out before the ground.
    // Strictly masked by isSky so it NEVER appears through terrain or entities.
    // This runs BEFORE volumetric clouds are rendered, so clouds naturally block these rays!
    vec3 cloudGodRays = vec3(0.0);
    #if CLOUD_TYPE != 0 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
    if (isEyeInWater == 0 && isSky) {
        // Fade out halfway down the sky so no shafts appear on the ground
        float skyMask = smoothstep(-0.1, 0.3, nFeetPlayerPos.y);
        if (skyMask > 0.0) {
            vec3 sunDir = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
            #ifndef FORCE_DISABLE_DAY_CYCLE
                if (dayCycle < 1.0) sunDir = -sunDir;
            #endif

            // Match the exact origin and slab bounds used in skyRender.glsl
            vec3 cloudOrigin = vec3(cameraPosition.x + fragmentFrameTime, cameraPosition.y - volumetricCloudHeight, cameraPosition.z);
            float slabTop = 0.0;
            float slabBottom = -VOLUMETRIC_CLOUD_DEPTH;
            float t3D = mod(fragmentFrameTime * 0.02, 10000.0);

            float maxDist = 3000.0;
            uint cSteps = 4u;
            float stepSize = maxDist / float(cSteps);

            // Phase function makes the rays brighter when looking towards the sun
            float phase = cloudPhaseFunction(clamp(dot(nFeetPlayerPos, sunDir), -1.0, 1.0), 0.8);
            float transmittance = 1.0;

            for (uint i = 0u; i < cSteps; i++) {
                // Raymarch in cloud space (origin is cloudOrigin)
                vec3 rayPos = cloudOrigin + nFeetPlayerPos * ((float(i) + dither) * stepSize);
                
                // Get cloud transmittance (1 = gap in clouds, 0 = thick cloud)
                float cShadow = getVolumetricCloudShadow(rayPos, sunDir, cloudOrigin, slabTop, slabBottom, t3D);
                float cloudOpacity = 1.0 - cShadow;
                
                // Light reaching this point from the sun
                vec3 lightAtP = lightCol * cShadow;
                
                // Light scattered towards the camera
                float airScatter = 0.05 * phase;
                cloudGodRays += lightAtP * airScatter * transmittance;
                
                // Attenuation of the view ray (air + clouds)
                transmittance *= (1.0 - airScatter - cloudOpacity * 0.1);
                if (transmittance < 0.01) break;
            }
            
            // Apply masks and MASSIVELY boost intensity so the rays are visible
            cloudGodRays *= skyMask * VOLUMETRIC_LIGHTING_STRENGTH; 
        }
    }
    #endif

    #if defined VOLUMETRIC_LIGHTING && defined SHADOW_MAPPING
        // Check if underwater - use shadow-based volumetric light for water godrays
        if(isEyeInWater == 1) {
            // Use shadow sampling for caustic-based godrays (similar to global volumetric light)
            vec3 endPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * (mat3(shadowModelView) * nFeetPlayerPos);
            endPos *= min(min(borderFar, shadowDistance), feetPlayerDist) * volumetricStepsInverse;

            vec3 startPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowModelView[3].xyz + endPos * dither;
            startPos.z += shadowProjection[3].z;

            vec3 causticVolumeData = vec3(0);
            for(uint i = 0u; i < VOLUMETRIC_LIGHT_STEPS; i++){
                // Sample shadow colors which include caustic information
                causticVolumeData += getShdCol(vec3(startPos.xy / (length(startPos.xy) * 2.0 + 0.2), startPos.z * 0.1) + 0.5);
                startPos += endPos;
            }

            // Use caustic shadow data to create godrays
            vec3 godrayLight = causticVolumeData * lightCol * (min(2.0, VOLUMETRIC_LIGHTING_STRENGTH * underwaterBoost * 3.0) * squared(heightFade) * volumetricFogDensity * volumetricStepsInverse) * bloomMult;

            // Add base underwater volumetric light
            vec3 baseVolumetric = lightCol * toLinear(fogColor) * (min(2.0, VOLUMETRIC_LIGHTING_STRENGTH * underwaterBoost * 2.0) * squared(heightFade) * volumetricFogDensity * 0.5) * bloomMult;

            return baseVolumetric + godrayLight;
        }
        
        // Normal shadow-mapped volumetric light for above water
        vec3 endPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * (mat3(shadowModelView) * nFeetPlayerPos);
        float marchDist = min(min(borderFar, shadowDistance), feetPlayerDist);
        endPos *= marchDist * volumetricStepsInverse;

        vec3 startPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowModelView[3].xyz + endPos * dither;
        startPos.z += shadowProjection[3].z;

        vec3 volumeData = vec3(0);

        for(uint i = 0u; i < VOLUMETRIC_LIGHT_STEPS; i++){
            volumeData += getShdCol(vec3(startPos.xy / (length(startPos.xy) * 2.0 + 0.2), startPos.z * 0.1) + 0.5);
            startPos += endPos;
        }
        
        // Return terrain godrays (normal) + sky cloud godrays
        vec3 terrainGodRays = volumeData * lightCol * (min(1.0, VOLUMETRIC_LIGHTING_STRENGTH * underwaterBoost) * squared(heightFade) * volumetricFogDensity * volumetricStepsInverse) * bloomMult;
        return terrainGodRays + cloudGodRays * bloomMult;
    #else
        // Non-shadow-mapped volumetric light
        if(isEyeInWater == 1) {
            // Compute caustic at player's world position for godray modulation
            vec2 worldPosXZ = nFeetPlayerPos.xz + cameraPosition.xz;
            float animateTime = fragmentFrameTime * 0.0625;
            float caustic = getWaveCaustic(worldPosXZ, animateTime);
            caustic = saturate(caustic * WATER_CAUSTIC_BRIGHTNESS);

            // Create underwater godrays by directly adding caustic light
            vec3 godrayLight = lightCol * caustic * 2.0; // Strong caustic contribution for godrays

            // Modulate volumetric light with caustic pattern for underwater godrays
            float causticMod = 1.0 + caustic * 4.0; // Strong boost where caustics are bright

            vec3 baseVolumetric = lightCol * toLinear(fogColor) * (min(2.0, VOLUMETRIC_LIGHTING_STRENGTH * underwaterBoost * 2.0) * squared(heightFade) * volumetricFogDensity * causticMod) * bloomMult;

            // Combine base volumetric with godray light
            return baseVolumetric + godrayLight;
        }

        #ifdef WORLD_CUSTOM_SKYLIGHT
            else return lightCol * (volumetricFogDensity * VOLUMETRIC_LIGHTING_STRENGTH) * bloomMult + cloudGodRays * bloomMult;
        #else
            else return lightCol * (squared(eyeBrightFact) * volumetricFogDensity * VOLUMETRIC_LIGHTING_STRENGTH) * bloomMult + cloudGodRays * bloomMult;
        #endif
    #endif
}