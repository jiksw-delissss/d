/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: TAA jittering, simple shading, and world curvature

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///
#ifdef END
    // End dimension has no day/night cycle uniforms — provide constants instead
    #define dayCycle 1.0
    #define dayCycleAdjust 1.0
    #define rainStrength 0.0
#endif

#ifdef NETHER
    #define dayCycle 1.0
    #define dayCycleAdjust 1.0
    #define rainStrength 0.0
#endif
#ifdef VERTEX
    flat out int blockId;

    flat out vec2 lmCoord;

    flat out vec3 vertexNormal;

    out float vertexViewDist;

    out vec2 waterNoiseUv;

    out vec3 vertexColor;
    out vec3 vertexFeetPlayerPos;
    out vec3 vertexWorldPos;

    uniform vec3 cameraPosition;

    uniform mat4 gbufferModelViewInverse;

    #ifdef WORLD_CURVATURE
        uniform mat4 gbufferModelView;
    #endif

    #ifdef WORLD_LIGHT
        uniform mat4 shadowModelView;
    #endif
    
    #if ANTI_ALIASING == 2
        uniform int frameMod;

        uniform float pixelWidth;
        uniform float pixelHeight;

        #include "/lib/utility/taaJitter.glsl"
    #endif
    
    void main(){
        // Get block id
        blockId = dhMaterialId;
        // Distant horizons terrain color is stored here
        vertexColor = gl_Color.rgb;

        // Distant horizons lightmap calculation
        #ifdef WORLD_CUSTOM_SKYLIGHT
            lmCoord = vec2(min((gl_MultiTexCoord1.x - 0.03125) * 1.06666667, 1.0), WORLD_CUSTOM_SKYLIGHT);
        #else
            lmCoord = min((gl_MultiTexCoord1.xy - 0.03125) * 1.06666667, vec2(1));
        #endif

        // Get vertex normal
        vertexNormal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * fastNormalize(gl_Normal));

        // Get vertex view position
        vec3 vertexViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
        // Get vertex feet player position
        vertexFeetPlayerPos = mat3(gbufferModelViewInverse) * vertexViewPos + gbufferModelViewInverse[3].xyz;
        // Output view distance
        vertexViewDist = length(vertexViewPos) + 8.0;

        // Get world position
        vertexWorldPos = vertexFeetPlayerPos + cameraPosition;

        // Get water noise uv position
        waterNoiseUv = vertexWorldPos.xz * waterTileSizeInv;

        #ifdef WORLD_CURVATURE
            // Apply curvature distortion
            vertexFeetPlayerPos.y -= lengthSquared(vertexFeetPlayerPos.xz) * worldCurvatureInv;

            // Convert back to vertex view position
            vertexViewPos = mat3(gbufferModelView) * vertexFeetPlayerPos + gbufferModelView[3].xyz;
        #endif

        // Convert to clip position and output as final position
        // gl_Position = gl_ProjectionMatrix * vertexViewPos;
        gl_Position.xyz = getMatScale(mat3(gl_ProjectionMatrix)) * vertexViewPos;
        gl_Position.z += gl_ProjectionMatrix[3].z;

        gl_Position.w = -vertexViewPos.z;

        #if ANTI_ALIASING == 2
            gl_Position.xy += jitterPos(gl_Position.w);
        #endif
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    /* RENDERTARGETS: 4,1,2,3 */
    layout(location = 0) out vec4 sceneColOut; // colortex4
    layout(location = 1) out vec3 normalDataOut; // colortex1
    layout(location = 2) out vec3 albedoDataOut; // colortex2
    layout(location = 3) out vec3 materialDataOut; // colortex3

    flat in int blockId;

    flat in vec2 lmCoord;

    flat in vec3 vertexNormal;

    in float vertexViewDist;

    in vec2 waterNoiseUv;

    in vec3 vertexColor;
    in vec3 vertexFeetPlayerPos;
    in vec3 vertexWorldPos;

    uniform int isEyeInWater;

    uniform float far;
    uniform float borderFar;

    uniform float nightVision;
    uniform float lightningFlash;

    uniform mat4 gbufferProjectionInverse;
    // Needed by the included raytracer implementation
    uniform mat4 gbufferProjection;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform mat4 gbufferModelViewInverse;
    // Distant Horizons projection inverse for DH depth reconstruction
    uniform mat4 dhProjectionInverse;

    uniform sampler2D depthtex0;
    uniform sampler2D dhDepthTex0;
    uniform sampler2D dhDepthTex1;
    // HDR scene buffers (required by SSR/reflection sampling)
    uniform sampler2D colortex4;
    #ifdef PREVIOUS_FRAME
        uniform sampler2D colortex5;
    #endif
    // Blue-noise / dither texture is provided by /lib/utility/noiseFunctions.glsl

    #ifndef FORCE_DISABLE_WEATHER
        uniform float rainStrength;
    #endif

    // Always needed for depth-based water color gradient
    uniform float dhNearPlane;

    #ifndef FORCE_DISABLE_DAY_CYCLE
        uniform float dayCycle;
        uniform float dayCycleAdjust;
        uniform float twilightPhase;
    #endif

    #ifdef WORLD_VANILLA_FOG_COLOR
        uniform vec3 fogColor;
    #endif

    #ifdef WORLD_CUSTOM_SKYLIGHT
        const float eyeBrightFact = WORLD_CUSTOM_SKYLIGHT;
    #else
        uniform float eyeSkylight;
        
        float eyeBrightFact = eyeSkylight;
    #endif

    #ifdef WORLD_LIGHT
        uniform float shdFade;

        uniform mat4 shadowModelView;

        #ifdef SHADOW_MAPPING
            uniform mat4 shadowProjection;

            #include "/lib/lighting/shdMapping.glsl"
        #endif

        #include "/lib/lighting/GGX.glsl"
    #endif

    #include "/lib/PBR/dataStructs.glsl"

    #include "/lib/utility/noiseFunctions.glsl"

    #if defined WATER_NORMAL || defined WATER_NOISE
        uniform float fragmentFrameTime;

        #include "/lib/surface/water.glsl"
    #endif

    #if defined ENVIRONMENT_PBR && !defined FORCE_DISABLE_WEATHER
        uniform float isPrecipitationRain;

        #include "/lib/PBR/enviroPBR.glsl"
    #endif

    #include "/lib/util/waterColoring.glsl"
    // Ensure depth helpers and raytracer are available so DH LOD can use SSR
    #if defined SSR || defined SSGI
        #include "/lib/utility/projectionFunctions.glsl"
        #include "/lib/utility/depthTex.glsl"
        // Minimal fallback sky reflection for DH (avoid pulling full skyRender dependencies)
        #ifndef HAS_SIMPLE_SKY_REFLECTION
        #define HAS_SIMPLE_SKY_REFLECTION
        vec3 getSkyReflection(in vec3 reflectViewDir){
            vec3 sky = toLinear(SKY_COLOR_DATA_BLOCK);
            float up = clamp(reflectViewDir.y * 0.5 + 0.5, 0.0, 1.0);
            // Blend horizon/dome: more upward-facing returns brighter sky
            return sky * (0.25 + 0.75 * up) + vec3(lightningFlash) * 0.0;
        }
        #endif
        #include "/lib/rayTracing/rayTracer.glsl"
    #endif

    #include "/lib/modded/distantHorizons/complexShadingLOD.glsl"

    void main(){
        // Prevents overdraw
        if(far > vertexViewDist){ discard; return; }

        // Fix for Distant Horizons translucents rendering over real geometry
        if(texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).x != 1.0){ discard; return; }

        vec2 noiseUv = vertexWorldPos.zy * vertexNormal.x + vertexWorldPos.xz * vertexNormal.y + vertexWorldPos.xy * vertexNormal.z;
        vec2 noiseCol = texelFetch(noisetex, ivec2(noiseUv * 4.0) & 255, 0).xy;
        float dhNoise = (noiseCol.x + noiseCol.y) * 0.2 + 0.8;

        // Declare materials
        dataPBR material;
        material.normal = vertexNormal;
        material.albedo = vec4(min(vertexColor * dhNoise, vec3(1)), 1);

        #if COLOR_MODE == 1
            material.albedo.rgb = vec3(1);
        #elif COLOR_MODE == 2
            material.albedo.rgb = vec3(0);
        #elif COLOR_MODE == 3
            material.albedo.rgb = vertexColor;
        #endif

        material.smoothness = 0.96; material.emissive = 0.0;
        material.metallic = 0.04; material.porosity = 0.0;
        material.ss = 0.0;
        
        // Currently unused
        material.parallaxShd = 1.0;
        material.ambient = 1.0;

        // If water
        if(blockId == DH_BLOCK_WATER){
            float waterNoise = WATER_BRIGHTNESS;

            #ifdef WATER_NORMAL
                // Directly calling the real H2NWater function to perfectly match chunk water
                vec4 waterData = H2NWater(waterNoiseUv).xzyw;
                waterData.y = max(waterData.y, DH_WATER_BLUR_SIZE * 0.5);
                material.normal = fastNormalize(waterData.yxz * vertexNormal.x + waterData.xyz * vertexNormal.y + waterData.xzy * vertexNormal.z);
                #ifdef WATER_NOISE
                    waterNoise *= squared(0.128 + waterData.w * 0.5);
                #endif
            #elif defined WATER_NOISE
                float waterData = getCellNoise(waterNoiseUv);
                waterNoise *= squared(0.128 + waterData * 0.5);
            #endif

            #if defined WATER_STYLIZE_ABSORPTION || defined WATER_FOAM
                float waterDepth = dhNearPlane / (1.0 - gl_FragCoord.z) - dhNearPlane / (1.0 - texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x);
            #endif

            // Always compute real depth for color gradient
            float dhWaterDepth = clamp(
                dhNearPlane / (1.0 - gl_FragCoord.z) - dhNearPlane / (1.0 - texelFetch(dhDepthTex1, ivec2(gl_FragCoord.xy), 0).x),
                0.0, 16.0
            );

            #ifdef WATER_STYLIZE_ABSORPTION
                if(isEyeInWater == 0){
                    float depthBrightness = exp2(waterDepth * 0.25);
                    material.albedo.a = fastSqrt(material.albedo.a) * (1.0 - depthBrightness);
                }
            #endif

            // Day/night factor
            // ================================================================
            // ECLIPSE-DERIVED WATER COLORING (DH)
            // ================================================================

            #ifdef FORCE_DISABLE_DAY_CYCLE
                float dhDayAmt = 1.0;
            #else
                float dhDayAmt = clamp(dayCycleAdjust, 0.0, 1.0);
            #endif

            vec3 dhWaterCol = _sildurWaterColor(dhWaterDepth, dhDayAmt);
            material.albedo.rgb = dhWaterCol * waterNoise;
            material.metallic   = 0.0;
            
            // Match real water smoothness to ensure sun reflection spread matches
            float baseSmooth = mix(0.90, 0.95, clamp(dhWaterDepth * 0.06, 0.0, 1.0));
            material.smoothness = clamp(baseSmooth, 0.72, 0.96);
            material.emissive   = 0.0;

            #ifdef WATER_FOAM
                material.albedo = min(vec4(1), material.albedo + exp2((waterDepth + 0.0625) * 8.0));
            #endif
        }

        // Convert to linear space
        material.albedo.rgb = toLinear(material.albedo.rgb);

        #if defined ENVIRONMENT_PBR && !defined FORCE_DISABLE_WEATHER
            if(blockId != DH_BLOCK_WATER) enviroPBR(material, vertexNormal);
        #endif

        // Apply simple shading
        sceneColOut = vec4(complexShadingLOD(material).rgb, material.albedo.a);

        // Write buffer datas
        normalDataOut = material.normal;
        albedoDataOut = material.albedo.rgb;
        materialDataOut = vec3(material.metallic, material.smoothness, 0.5);
    }
#endif