/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

#extension GL_ARB_shader_image_load_store : require
#extension GL_ARB_gpu_shader5 : require
#extension GL_ARB_shading_language_packing : require

/// Buffer features: Solid complex shading

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    flat out vec3 skyCol;

    noperspective out vec2 texCoord;

    #ifdef WORLD_LIGHT
        flat out vec3 sRGBLightCol;
        flat out vec3 lightCol;

        #ifndef FORCE_DISABLE_DAY_CYCLE
            flat out vec3 sRGBSunCol;
            flat out vec3 sunCol;
            flat out vec3 sRGBMoonCol;
            flat out vec3 moonCol;
        #endif
    #endif

    #ifndef FORCE_DISABLE_WEATHER
        uniform float rainStrength;
    #endif

    #ifndef FORCE_DISABLE_DAY_CYCLE
        uniform float dayCycle;
        uniform float twilightPhase;
    #endif

    #ifdef WORLD_VANILLA_FOG_COLOR
        uniform vec3 fogColor;
    #endif

    void main(){
        // Get buffer texture coordinates
        texCoord = gl_MultiTexCoord0.xy;

        skyCol = toLinear(SKY_COLOR_DATA_BLOCK);

        #ifdef WORLD_LIGHT
            #ifdef FORCE_DISABLE_DAY_CYCLE
                sRGBLightCol = LIGHT_COLOR_DATA_BLOCK0;
                lightCol = toLinear(sRGBLightCol);
            #else
                sRGBSunCol = SUN_COL_DATA_BLOCK;
                sunCol = toLinear(sRGBSunCol);
                sRGBMoonCol = MOON_COL_DATA_BLOCK;
                moonCol = toLinear(sRGBMoonCol);

                sRGBLightCol = LIGHT_COLOR_DATA_BLOCK1(sRGBSunCol, sRGBMoonCol);
                lightCol = toLinear(sRGBLightCol);
            #endif
        #endif

        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0, 1);
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    /* RENDERTARGETS: 4,6 */
    layout(location = 0) out vec3 sceneColOut;
    layout(location = 1) out vec3 opaqueSnapshot;

    // Explicitly enable Screen Space Global Illumination
    #define SSGI

    flat in vec3 skyCol;

    #ifdef WORLD_LIGHT
        flat in vec3 sRGBLightCol;
        flat in vec3 lightCol;

        #ifndef FORCE_DISABLE_DAY_CYCLE
            flat in vec3 sRGBSunCol;
            flat in vec3 sunCol;
            flat in vec3 sRGBMoonCol;
            flat in vec3 moonCol;
        #endif
    #endif

    noperspective in vec2 texCoord;

    uniform int isEyeInWater;

    uniform float borderFar;

    uniform float far;
    uniform float near;

    uniform float nightVision;
    uniform float effectFactor;
    uniform float lightningFlash;
    uniform float darknessLightFactor;

    uniform float fragmentFrameTime;

    uniform vec3 fogColor;

    uniform vec3 cameraPosition;


    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;

    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;

    uniform mat4 shadowModelView;

    // Main HDR buffer
    uniform sampler2D colortex4;
    uniform sampler2D colortex1;
    // For SSAO and material masks
    uniform sampler2D colortex2;
    uniform sampler2D colortex3;
    
    uniform sampler2D depthtex0;
    uniform sampler2D depthtex1;

    #ifdef USE_LIGHTMAP
        uniform sampler2D lightmap;
    #endif

    #ifdef WORLD_LIGHT
        uniform float shdFade;

        #ifdef SHADOW_MAPPING
            uniform mat4 shadowProjection;

            #include "/lib/lighting/shdMapping.glsl"
        #endif

        // World-space RSM GI uniforms
        #ifndef SHADOW_MAPPING
            uniform mat4 shadowProjection;
        #endif

        uniform float viewWidth;
        uniform float viewHeight;
        uniform float pixelWidth;
        uniform float pixelHeight;

        #include "/lib/utility/noiseFunctions.glsl"
    #endif

    #if ANTI_ALIASING >= 2
        uniform float frameFract;
    #endif

    #ifndef FORCE_DISABLE_WEATHER
        uniform float rainStrength;
    #endif

    #ifndef FORCE_DISABLE_DAY_CYCLE
        uniform float dayCycle;
        uniform float dayCycleAdjust;
    #endif

    #if CLOUD_TYPE != 0 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
        uniform sampler2D colortex0;
    #endif

    #ifdef DISTANT_HORIZONS
        uniform mat4 dhProjectionInverse;

        uniform sampler2D dhDepthTex0;

        bool isDHBoundary(in ivec2 coord, bool currentDH) {
            ivec2 offs[4];
            offs[0] = ivec2(1, 0);
            offs[1] = ivec2(-1, 0);
            offs[2] = ivec2(0, 1);
            offs[3] = ivec2(0, -1);

            for (int i = 0; i < 4; i++) {
                float neighborMainDepth = texelFetch(depthtex0, coord + offs[i], 0).x;
                bool neighborDH = neighborMainDepth >= 1.0;
                if (neighborDH != currentDH) {
                    return true;
                }
            }
            return false;
        }
    #else
        // Provide minimal fallbacks so the shader compiles when Distant Horizons
        // is not enabled/installed. When DH is unavailable these stubs are
        // unused at runtime but prevent undefined-variable/undefined-function
        // compilation errors from included code paths.
        uniform sampler2D dhDepthTex0;
        bool isDHBoundary(in ivec2 coord, bool currentDH) { return false; }
    #endif

    #ifdef WORLD_CUSTOM_SKYLIGHT
        const float eyeBrightFact = WORLD_CUSTOM_SKYLIGHT;
    #else
        uniform float eyeSkylight;
        
        float eyeBrightFact = eyeSkylight;
    #endif

    #include "/lib/utility/projectionFunctions.glsl"

    // Ensure raytracer is loaded for SSR, SSGI, or RT reflections
    #if defined SSR || defined SSGI
        #include "/lib/utility/depthTex.glsl"
        #include "/lib/rayTracing/rayTracer.glsl"
    #endif

    #if defined(VOXEL_RT_REFLECTIONS)
        layout(r32ui) uniform uimage3D cimage1;
        #include "/lib/rt/rtTrace.glsl"
    #endif

    #if defined SSR && defined PREVIOUS_FRAME
        uniform vec3 camPosDelta;

        uniform mat4 gbufferPreviousModelView;
        uniform mat4 gbufferPreviousProjection;

        uniform sampler2D colortex5;

        #include "/lib/utility/prevProjectionFunctions.glsl"
    #endif

    #ifdef SSAO
        float getSSAOBoxBlur(in ivec2 screenTexelCoord){
            ivec2 topRightCorner = screenTexelCoord + 1;
            ivec2 bottomLeftCorner = screenTexelCoord - 1;

            float sample0 = texelFetch(colortex2, topRightCorner, 0).a;
            float sample1 = texelFetch(colortex2, bottomLeftCorner, 0).a;
            float sample2 = texelFetch(colortex2, ivec2(topRightCorner.x, bottomLeftCorner.y), 0).a;
            float sample3 = texelFetch(colortex2, ivec2(bottomLeftCorner.x, topRightCorner.y), 0).a;

            return sample0 + sample1 + sample2 + sample3;
        }
    #endif

    // Always include outline helpers so we can fallback at runtime if options are disabled
    #include "/lib/post/outline.glsl"
    #include "/lib/post/outline_cartoon.glsl"


    // Define camera height for atmospheric scattering
    const float camera_height = 50.0;

    #include "/lib/atmospherics/skyRender.glsl"
    #include "/lib/atmospherics/fogRender.glsl"

    #if CLOUD_TYPE != 0 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
        #include "/lib/rayTracing/volumetricClouds.glsl"
    #endif

    #include "/lib/lighting/complexShadingDeferred.glsl"

    void main(){
        // Screen texel coordinates
        ivec2 screenTexelCoord = ivec2(gl_FragCoord.xy);

        bool realSky = false;

        float depth = texelFetch(depthtex0, screenTexelCoord, 0).x;

        // Distant Horizons apparently uses a different depth texture
        #ifdef DISTANT_HORIZONS
            realSky = depth == 1;
            if(realSky) depth = texelFetch(dhDepthTex0, screenTexelCoord, 0).x;
        #endif

        // Get screen pos
        vec3 screenPos = vec3(texCoord, depth);

        // Distant Horizons apparently uses a different projection matrix
        #ifdef DISTANT_HORIZONS
            vec3 viewPos = getViewPos(realSky ? dhProjectionInverse : gbufferProjectionInverse, screenPos);
        #else
            vec3 viewPos = getViewPos(gbufferProjectionInverse, screenPos);
        #endif

        // Get eye player pos
        vec3 eyePlayerPos = mat3(gbufferModelViewInverse) * viewPos;

        // Get view distance
        float viewDot = lengthSquared(viewPos);
        float viewDotInvSqrt = inversesqrt(viewDot);
        float viewDist = viewDot * viewDotInvSqrt; // Moved up here!

        // Get normalized eyePlayerPos
        vec3 nEyePlayerPos = eyePlayerPos * viewDotInvSqrt;

        // Get scene color
        sceneColOut = texelFetch(colortex4, screenTexelCoord, 0).rgb;

        // Get sky pos by shadow model view
        vec3 skyPos = mat3(shadowModelView) * nEyePlayerPos;

        #if defined WORLD_LIGHT && !defined FORCE_DISABLE_DAY_CYCLE
            // Flip if the sun has gone below the horizon
            if(dayCycle < 1) skyPos.xz = -skyPos.xz;
        #endif

        // Get basic sky simple color (scattering-based)
        vec3 currSkyCol = getSkyBasic(nEyePlayerPos, skyPos, realSky);

        // If sky, do full sky render and return immediately
        if(screenPos.z == 1){
            // Calculate custom sky render
            vec3 customSky = getFullSkyRender(nEyePlayerPos, skyPos, currSkyCol + sceneColOut) * exp2(-borderFar * effectFactor);
            
            // Blend custom sky with vanilla skybox (which is already in sceneColOut)
            sceneColOut = mix(sceneColOut, customSky, 0.9); // 70% custom sky, 30% vanilla skybox
            
            // Exit function immediately
            return;
        }

        #if ANTI_ALIASING >= 2
            vec3 dither = fract(getRng3(screenTexelCoord & 255) + frameFract);
        #else
            vec3 dither = getRng3(screenTexelCoord & 255);
        #endif

        // Declare and get materials
        vec2 matRaw0 = texelFetch(colortex3, screenTexelCoord, 0).xy;
        vec3 albedo = texelFetch(colortex2, screenTexelCoord, 0).rgb;
        vec3 normal = texelFetch(colortex1, screenTexelCoord, 0).xyz;

        // Apply shadow for distant horizon terrain using Screen Space Shadows
        #if defined(WORLD_LIGHT) && defined(DISTANT_HORIZONS)
        if(realSky && depth < 1.0){
            vec3 lightDirWorld = vec3(shadowModelView[0].z, shadowModelView[1].z, shadowModelView[2].z);
            
            if(lightDirWorld.y > 0.0){
                vec3 lightDirView = normalize(mat3(gbufferModelView) * lightDirWorld);
                
                // Calculate sunlight strength based on normal (exactly as complexShadingLOD does)
                float NLZ = dot(normal, lightDirWorld);
                float dirLight = max(0.0, NLZ);
                
                int steps = 64;
                float stepSize = 0.3;
                vec3 rayPos = viewPos + lightDirView * 16.0; // Start 1 block away to avoid self-shadow
                float shadow = 1.0;
                
                for(int i = 0; i < steps; i++){
                    rayPos += lightDirView * stepSize;
                    
                    vec4 clipPos = gbufferProjection * vec4(rayPos, 1.0);
                    vec3 ndc = clipPos.xyz / clipPos.w;
                    vec2 uv = ndc.xy * 0.5 + 0.5;
                    
                    if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || ndc.z > 1.0) break;
                    
                    float vanillaDepth = textureLod(depthtex0, uv, 0).x;
                    float dhDepth = textureLod(dhDepthTex0, uv, 0).x;
                    
                    vec3 sampleView;
                    if(vanillaDepth < 1.0){
                        sampleView = getViewPos(gbufferProjectionInverse, vec3(uv, vanillaDepth));
                    } else {
                        sampleView = getViewPos(dhProjectionInverse, vec3(uv, dhDepth));
                    }
                    
                    float diff = rayPos.z - sampleView.z;
                    
                    // If sample is closer to camera (diff < 0) and within reasonable range, it's a shadow
                    if(diff < -0.05 && diff > -8.0){
                        shadow = 0.0;
                        break;
                    }
                }
                
                // Remove the exact amount of direct sunlight added in complexShadingLOD
                // This leaves ambient/sky light perfectly intact, matching real shadowmap darkness
            vec3 sunLightAdded = albedo * lightCol * dirLight * shdFade;
                sceneColOut = max(sceneColOut - sunLightAdded * (1.0 - shadow), vec3(0.0));
            }
        }
        #endif

        // Apply deffered shading (Applies GI, RT reflections, and Cel Shading)
        sceneColOut = complexShadingDeferred(sceneColOut, screenPos, viewPos, mat3(gbufferModelView) * normal, albedo, dither, viewDotInvSqrt, matRaw0.x, matRaw0.y, 0.0, realSky);

        // Apply volumetric cloud shadows to ALL terrain (Vanilla and DH)
        #if CLOUD_TYPE != 0 && !defined FORCE_DISABLE_CLOUDS && defined WORLD_LIGHT
        if (depth < 1.0) {
            // Calculate world position of terrain
            vec3 feetPlayerPos = eyePlayerPos + gbufferModelViewInverse[3].xyz;
            
            // Get sun direction in world space
            vec3 sunDir = normalize(transpose(mat3(shadowModelView)) * vec3(0., 0., 1.));
            #ifndef FORCE_DISABLE_DAY_CYCLE
                if (dayCycle < 1.0) sunDir = -sunDir;
            #endif
            
            // Use the exact same cloud origin and slab bounds as the sky render
            vec3 cloudOrigin = vec3(cameraPosition.x + fragmentFrameTime, cameraPosition.y - volumetricCloudHeight, cameraPosition.z);
            float slabTop = 0.0;
            float slabBottom = -VOLUMETRIC_CLOUD_DEPTH * 6.0;
            float t3D = mod(fragmentFrameTime * 0.02, 10000.0);
            
            // Convert terrain world position to cloud space
            vec3 feetPlayerPosCloudSpace = feetPlayerPos - vec3(0.0, volumetricCloudHeight, 0.0);
            
            // Compute cloud shadow transmittance (0 = fully shadowed, 1 = no shadow)
            float cloudShadow = getVolumetricCloudShadow(feetPlayerPosCloudSpace, sunDir, cloudOrigin, slabTop, slabBottom, t3D);
            
            // Prevent shadows from being pitch black at noon (clamp minimum brightness to 40%)
            cloudShadow = max(cloudShadow, 0.8);
            
            // SKY EXPOSURE CHECK: Use surface normal to determine if the block is exposed to the sky.
            // If the normal points up or slightly sideways, it is exposed. Ceilings (normal.y < 0) are not.
            float skyExposure = clamp(dot(normal, vec3(0.0, 1.0, 0.0)) * 1.5 + 0.2, 0.0, 1.0);
            cloudShadow = mix(1.0, cloudShadow, skyExposure);
            
            // Apply consistent darkness across all daytime hours using dayCycle instead of sunHeight
            float shadowStrength = mix(1.0, cloudShadow, dayCycle);
            sceneColOut *= shadowStrength;
        }
        #endif

        // Fallback: compute and apply outline mask only when outlines are enabled.
        // This also applies to Distant Horizons geometry when it has a valid depth.
        #if OUTLINES != 0 || defined(CARTOON_OUTLINE_ENABLE)
        bool currentDH = realSky && depth < 1.0;
        if(!realSky || currentDH) {
            if(currentDH) {
                float outlineMask = getOutline(dhDepthTex0, screenTexelCoord, screenPos.z);
                float cartoonEdge = cartoon_detectOutlineDepth(dhDepthTex0, texCoord, screenPos.z, near, far);
                float edge = clamp(max(outlineMask * 0.8, cartoonEdge * 1.0), 0.0, 1.0);

                if(isDHBoundary(screenTexelCoord, currentDH)) {
                    edge = 0.0;
                }

                // Suppress edges that are likely internal seams by checking albedo and normal similarity
                vec3 centerAlbedo = texelFetch(colortex2, screenTexelCoord, 0).rgb;
                vec3 centerNormal = texelFetch(colortex1, screenTexelCoord, 0).xyz;

                float maxAlbedoDiff = 0.0;
                float maxNormalDiff = 0.0;
                ivec2 offs[4];
                offs[0] = ivec2(1,0);
                offs[1] = ivec2(-1,0);
                offs[2] = ivec2(0,1);
                offs[3] = ivec2(0,-1);
                for(int i=0;i<4;i++){
                    ivec2 nCoord = screenTexelCoord + offs[i];
                    vec3 a = texelFetch(colortex2, nCoord, 0).rgb;
                    vec3 n = texelFetch(colortex1, nCoord, 0).xyz;
                    maxAlbedoDiff = max(maxAlbedoDiff, length(a - centerAlbedo));
                    maxNormalDiff = max(maxNormalDiff, 1.0 - dot(n, centerNormal));
                }

                if(maxAlbedoDiff < 0.06 && maxNormalDiff < 0.12) {
                    edge = 0.0;
                }

                if(edge > 0.02) {
                    float strength = smoothstep(0.02, 0.9, edge);
                    sceneColOut = mix(sceneColOut, vec3(0.0), strength);
                }
            } else {
                float outlineMask = getOutline(depthtex0, screenTexelCoord, screenPos.z);
                float cartoonEdge = cartoon_detectOutlineDepth(depthtex0, texCoord, screenPos.z, near, far);
                float edge = clamp(max(outlineMask * 0.8, cartoonEdge * 1.0), 0.0, 1.0);

                if(isDHBoundary(screenTexelCoord, currentDH)) {
                    edge = 0.0;
                }

                // Suppress edges that are likely internal seams by checking albedo and normal similarity
                vec3 centerAlbedo = texelFetch(colortex2, screenTexelCoord, 0).rgb;
                vec3 centerNormal = texelFetch(colortex1, screenTexelCoord, 0).xyz;

                float maxAlbedoDiff = 0.0;
                float maxNormalDiff = 0.0;
                ivec2 offs[4];
                offs[0] = ivec2(1,0);
                offs[1] = ivec2(-1,0);
                offs[2] = ivec2(0,1);
                offs[3] = ivec2(0,-1);
                for(int i=0;i<4;i++){
                    ivec2 nCoord = screenTexelCoord + offs[i];
                    vec3 a = texelFetch(colortex2, nCoord, 0).rgb;
                    vec3 n = texelFetch(colortex1, nCoord, 0).xyz;
                    maxAlbedoDiff = max(maxAlbedoDiff, length(a - centerAlbedo));
                    maxNormalDiff = max(maxNormalDiff, 1.0 - dot(n, centerNormal));
                }

                if(maxAlbedoDiff < 0.06 && maxNormalDiff < 0.12) {
                    edge = 0.0;
                }

                if(edge > 0.02) {
                    float strength = smoothstep(0.02, 0.9, edge);
                    sceneColOut = mix(sceneColOut, vec3(0.0), strength);
                }
            }
        }
        #endif

        #ifdef SSAO
            // Apply ambient occlusion with simple blur
            sceneColOut *= getSSAOBoxBlur(screenTexelCoord);
        #endif

        // Get basic sky fog color
        vec3 fogSkyCol = getSkyFogRender(nEyePlayerPos, skyPos, currSkyCol);
        // Get fog factor
        float fogFactor = getFogFactor(viewDist, nEyePlayerPos.y, eyePlayerPos.y + gbufferModelViewInverse[3].y + cameraPosition.y);

        // Border fog
        #ifdef BORDER_FOG
            fogFactor = (fogFactor - 1.0) * getBorderFog(viewDist) + 1.0;
        #endif

        // Apply fog and darkness fog
        sceneColOut = ((fogSkyCol - sceneColOut) * fogFactor + sceneColOut) * getFogEffectFactor(viewDist);
        opaqueSnapshot = sceneColOut;
    }
#endif