vec4 complexShadingLOD(in dataPBR material){
    // Provide defaults for ripple spec variables in case the caller didn't declare them
    #ifndef RIPPLE_SPEC_VARS
    #define RIPPLE_SPEC_VARS
        vec3 rippleSpecNormal = vec3(0.0);
        float rippleSpecBlend = 0.0;
    #endif
    // Define block light color
    const vec3 blockLightColor = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * (BLOCKLIGHT_I * 0.00392156863);
    // Calculate sky diffusion first, begining with the sky itself
    vec3 totalIllumination = toLinear(SKY_COLOR_DATA_BLOCK);

    // Calculate thunder flash
    totalIllumination += lightningFlash;

    // Get block light squared
    float blockLightSquared = squared(lmCoord.x);
    // Get sky light squared
    float skyLightSquared = squared(lmCoord.y);

    // Occlude the appled sky and thunder flash calculation by sky light amount
    totalIllumination *= skyLightSquared;

    // Lastly, calculate ambient lightning
    totalIllumination += toLinear(AMBIENT_LIGHTING + nightVision * 0.5);

    // Calculate block light
    totalIllumination += toLinear((float(material.emissive == 0) * 0.25 + 1.0) * blockLightSquared * blockLightColor);

    #ifdef WORLD_LIGHT
        // Get sRGB light color
        vec3 sRGBLightCol = LIGHT_COLOR_DATA_BLOCK0;

        float NLZ = dot(material.normal, vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z));
        
        bool isShadow = NLZ > 0;

        // Removed fake vanilla ambient lightmap shadow. 
        // We use full shdFade so the deferred pass can accurately subtract the sun light.
        float shdCol = shdFade;

        float dirLight = isShadow ? NLZ : 0.0;

        #ifdef SUBSURFACE_SCATTERING
            // Diffuse with simple SS approximation
            if(material.ss > 0) dirLight += (1.0 - dirLight) * material.ambient * material.ss * 0.5;
        #endif

        float finalShadowCol = shdCol * dirLight;

        #ifndef FORCE_DISABLE_WEATHER
            // Approximate rain diffusing light shadow
            float rainDiffuseAmount = rainStrength * 0.5;
            finalShadowCol *= 1.0 - rainDiffuseAmount;

            finalShadowCol += rainDiffuseAmount * material.ambient * skyLightSquared * (1.0 - shdFade);
        #endif

        // Calculate and add shadow diffuse
        totalIllumination += toLinear(sRGBLightCol) * finalShadowCol;
    #endif

    // Get view direction
    vec3 viewDir = -fastNormalize(vertexFeetPlayerPos);

    // Modified version of BSL's reflection PBR calculation
    float NV = dot(material.normal, viewDir);
    float smoothCosTheta = NV > 0 ? exp2(-9.28 * NV) * material.smoothness : material.smoothness;
    float oneMinusCosTheta = material.smoothness - smoothCosTheta;

    if(material.metallic <= 0.9) totalIllumination *= 1.0 - (smoothCosTheta + material.metallic * oneMinusCosTheta);
    else totalIllumination *= 1.0 - material.smoothness;

    // Apply emissives
    totalIllumination += material.emissive * EMISSIVE_INTENSITY;

    vec4 totalLighting = vec4(material.albedo.rgb * totalIllumination, material.albedo.a);

    #if defined WORLD_LIGHT && defined SPECULAR_HIGHLIGHTS
        if(isShadow){
            vec3 specNormal = material.normal;
            specNormal = (rippleSpecBlend > 0.0) ? normalize(mix(material.normal, rippleSpecNormal, rippleSpecBlend)) : material.normal;

            // Get specular GGX using possibly-distorted normal
            vec3 specCol = getSpecularBRDF(viewDir, specNormal, material.albedo.rgb, NLZ, NV, material.metallic, material.smoothness) * shdCol;
            
            // Boost sun reflection for bloom, keep moon reflection lower to prevent auto-exposure darkening
            #ifdef FORCE_DISABLE_DAY_CYCLE
                float specBoost = 4.0;
            #else
                float specBoost = dayCycle > 0.5 ? 4.0 : 1.5;
            #endif
            totalLighting.rgb += sunMoonIntensitySqrd * specCol * sRGBLightCol * specBoost;
            if(material.albedo.a != 1) totalLighting.a = min(maxOf(specCol) + totalLighting.a, 1.0);
        }
    #endif

    // SSR integration for Distant Horizons (forward path compatibility)
    #if defined(SSR) && defined(RAYTRACER_INCLUDED)
        // Compute initial screen-space position from the interpolated vertex position
        vec3 screenPos = getScreenPos(gbufferProjection, vertexFeetPlayerPos);
        // Reconstruct accurate view-space position from the depth buffer (handles DH layers)
        float mainDepth = textureLod(depthtex0, screenPos.xy, 0).x;
        float sampledDepth = getDepthTex(screenPos.xy);
        vec3 viewPos = (mainDepth >= 1.0) ? getViewPos(dhProjectionInverse, vec3(screenPos.xy, sampledDepth)) : getViewPos(gbufferProjectionInverse, vec3(screenPos.xy, sampledDepth));

        // Simple dither value (matches forward shaders)
        float dither = texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 255, 0).x * TAU;

        // Get view direction and reflected dir (view-space)
        vec3 nViewDir = -fastNormalize(viewPos);
        float NVref = dot(material.normal, nViewDir);
        vec3 reflectViewDir = reflect(nViewDir, material.normal);

        // Trace the scene using the shared raytracer helper
        vec3 SSRCoord = rayTraceScene(screenPos, viewPos, reflectViewDir, dither);

        vec3 reflectCol = vec3(0.0);
        bool reflectIsSky = false;

        if(SSRCoord.z < 0.5){
            // No hit: fallback to sky when appropriate
            vec3 reflDirN = normalize(reflectViewDir);
            bool reflLooksUp = reflDirN.y > -0.5;
            if(reflLooksUp){
                reflectCol = getSkyReflection(reflDirN);
                reflectIsSky = true;
            }
            else {
                // Fallback: sample the scene buffer near the reflected screen direction
                vec2 fallbackUv = clamp(screenPos.xy, vec2(0.0), vec2(1.0));
                ivec2 fallbackPix = ivec2(fallbackUv * vec2(viewWidth, viewHeight));
                reflectCol = texelFetch(colortex4, fallbackPix, 0).rgb * 0.45;
                reflectIsSky = false;
            }
        } else {
            // SSRCoord.xy contains pixel coordinates (returned from ray tracer)
            ivec2 samplePix = ivec2(SSRCoord.xy);
            reflectCol = texelFetch(colortex4, samplePix, 0).rgb;
            reflectIsSky = false;
        }

        // Fresnel blending using existing smoothness/metallic calculations
        float smoothCosThetaRef = NVref > 0.0 ? exp2(-9.28 * NVref) * material.smoothness : material.smoothness;
        float oneMinusCosThetaRef = material.smoothness - smoothCosThetaRef;

        if(material.metallic <= 0.9) totalLighting.rgb += reflectCol * (smoothCosThetaRef + material.metallic * oneMinusCosThetaRef);
        else totalLighting.rgb += reflectCol * (smoothCosThetaRef + material.albedo.rgb * oneMinusCosThetaRef);
    #endif

    return totalLighting;
}