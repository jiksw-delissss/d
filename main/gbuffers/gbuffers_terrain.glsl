/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: TAA jittering, complex shading, animation, lava noise, PBR, and world curvature

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    flat out int blockId;

    flat out mat3 TBN;

    out float vertexAO;

    out vec2 lmCoord;
    out vec3 blockLightColor;
    out vec2 texCoord;

    out vec3 vertexColor;
    out vec3 vertexFeetPlayerPos;
    out vec3 vertexWorldPos;

    #if defined NORMAL_GENERATION || defined PARALLAX_OCCLUSION
        flat out vec2 vTexCoordScale;
        flat out vec2 vTexCoordPos;

        out vec2 vTexCoord;
    #endif

    uniform vec3 cameraPosition;

    uniform mat4 gbufferModelViewInverse;

    #if defined TERRAIN_ANIMATION || defined WORLD_CURVATURE || defined FOLIAGE_TOUCH
        uniform mat4 gbufferModelView;
    #endif

    #if ANTI_ALIASING == 2
        uniform int frameMod;

        uniform float pixelWidth;
        uniform float pixelHeight;

        #include "/lib/utility/taaJitter.glsl"
    #endif

    #ifdef TERRAIN_ANIMATION
        uniform float vertexFrameTime;
        #ifdef RAIN_TRANSITION_UNIFORM
            uniform float lastRainToggleTime;
            uniform int lastRainToggleState;
            uniform float rainTransitionSeconds;
        #endif

        attribute vec3 at_midBlock;

        #include "/lib/vertex/waveTerrain.glsl"
    #endif

    // relativeEyePosition = cameraPosition - eyePosition (Iris standard uniform)
    // Offsets vertexFeetPlayerPos from camera back to true player head space.
    uniform vec3 relativeEyePosition;

    attribute vec3 mc_Entity;

    attribute vec4 at_tangent;

    #if defined NORMAL_GENERATION || defined PARALLAX_OCCLUSION || defined TERRAIN_ANIMATION
        attribute vec2 mc_midTexCoord;
    #endif

    #include "/lib/utility/coloredLighting.glsl"

    void main(){
        // Get block id
        blockId = int(mc_Entity.x);
        // Get vertex AO
        vertexAO = gl_Color.a;
        // Get buffer texture coordinates
        texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        // Get vertex color
        vertexColor = gl_Color.rgb;

        // Lightmap fix for mods + Colored Lighting support
        correctedLightMap();

        // Get vertex normal
        vec3 vertexNormal = fastNormalize(gl_Normal);
        // Get vertex tangent
        vec3 vertexTangent = fastNormalize(at_tangent.xyz);

        // Get vertex view position
        vec3 vertexViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
        // Get vertex feet player position
        vertexFeetPlayerPos = mat3(gbufferModelViewInverse) * vertexViewPos + gbufferModelViewInverse[3].xyz;

        // Get world position
        vertexWorldPos = vertexFeetPlayerPos + cameraPosition;

        // Calculate TBN matrix
	    TBN = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * mat3(vertexTangent, cross(vertexTangent, vertexNormal) * sign(at_tangent.w), vertexNormal));

        #if defined NORMAL_GENERATION || defined PARALLAX_OCCLUSION
            vec2 midTexCoord = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0, 0)).xy;
            vec2 texMinMidTexCoord = texCoord - midTexCoord;

            vTexCoordScale = abs(texMinMidTexCoord) * 2.0;
            vTexCoordPos = min(texCoord, midTexCoord - texMinMidTexCoord);
            vTexCoord = sign(texMinMidTexCoord) * 0.5 + 0.5;
        #endif

        #ifdef TERRAIN_ANIMATION
            // Apply terrain wave animation
            vertexFeetPlayerPos = getTerrainWave(vertexFeetPlayerPos, vertexWorldPos.xz, at_midBlock.y * 0.015625, mc_Entity.x, lmCoord.y, vertexFrameTime);
        #endif

        #ifdef FOLIAGE_TOUCH
            // PLANT TOUCH EFFECT (independent of terrain wave animation)
            // vertexFeetPlayerPos origin = player HEAD (not camera).
            // relativeEyePosition offsets from camera back to true player head space.
            //   playerRelPos = vertexFeetPlayerPos + relativeEyePosition
            vec3 playerRelPos = vertexFeetPlayerPos + relativeEyePosition;

            // Push direction: blade XZ relative to player head, pointing outward
            float bladeDist = length(playerRelPos.xz);
            vec2 outDir = (bladeDist > 0.01)
                ? playerRelPos.xz / bladeDist
                : vec2(1.0, 0.0);

            // Short grass (block.10603) and other short plants (block.10600)
            if(blockId == 10603 || blockId == 10600){
                vec3 touchPos = playerRelPos + vec3(0.0, 2.0, 0.0);
                if(length(touchPos) < 2.0){
                    float pushScale = max(
                        4.0 / pow(max(length(touchPos * vec3(8.0, 2.0, 8.0) - vec3(0.0, 2.0, 0.0)), 2.0), 1.0) - 0.625,
                        0.0
                    );
                    // Smooth falloff so edge of radius is gentle, center is strong
                    float proximity = 1.0 - smoothstep(0.0, 2.0, length(touchPos.xz));
                    vertexFeetPlayerPos.xz += outDir * pushScale * proximity * 0.4;
                }
            }

            // Tall grass / large fern upper half (block.10700)
            if(blockId == 10700){
                vec3 touchPos = playerRelPos;
                if(length(touchPos) < 2.0){
                    float pushScale = max(
                        4.0 / pow(max(length(touchPos * vec3(8.0, 2.0, 8.0)), 2.0), 1.0) - 0.625,
                        0.0
                    );
                    vertexFeetPlayerPos.xz += outDir * pushScale * 0.3;
                }
            }
        #endif

        #ifdef WORLD_CURVATURE
            // Apply curvature distortion
            vertexFeetPlayerPos.y -= dot(vertexFeetPlayerPos.xz, vertexFeetPlayerPos.xz) * worldCurvatureInv;
        #endif

        #if defined TERRAIN_ANIMATION || defined WORLD_CURVATURE || defined FOLIAGE_TOUCH
            // Convert back to vertex view position
            vertexViewPos = mat3(gbufferModelView) * vertexFeetPlayerPos + gbufferModelView[3].xyz;
        #endif

        // Convert to clip position and output as final position
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
    layout(location = 0) out vec3 sceneColOut; // colortex4
    layout(location = 1) out vec3 normalDataOut; // colortex1
    layout(location = 2) out vec3 albedoDataOut; // colortex2
    layout(location = 3) out vec3 materialDataOut; // colortex3

    flat in int blockId;

    flat in mat3 TBN;

    in float vertexAO;

    in vec2 lmCoord;
    in vec3 blockLightColor;
    in vec2 texCoord;

    in vec3 vertexColor;
    in vec3 vertexFeetPlayerPos;
    in vec3 vertexWorldPos;

    #if defined NORMAL_GENERATION || defined PARALLAX_OCCLUSION
        flat in vec2 vTexCoordScale;
        flat in vec2 vTexCoordPos;
        in vec2 vTexCoord;
    #endif

    // Enable full vanilla AO
    const float ambientOcclusionLevel = 1.0;

    uniform int isEyeInWater;

    uniform float nightVision;
    uniform float lightningFlash;

    uniform sampler2D gtexture;

    #ifndef FORCE_DISABLE_WEATHER
        uniform float rainStrength;
    #endif

    #if defined SHADOW_FILTER && ANTI_ALIASING >= 2
        uniform float frameFract;
    #endif

    #ifndef FORCE_DISABLE_DAY_CYCLE
        uniform float dayCycle;
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

    #if PBR_MODE <= 1
        #include "/lib/PBR/integratedPBR.glsl"
    #else
        #include "/lib/PBR/labPBR.glsl"
    #endif

    #include "/lib/utility/noiseFunctions.glsl"

    uniform float globalTime;
    uniform float fragmentFrameTime;

    const float RAIN_MIN_DEF = 0.12;

#ifdef RAIN_TRANSITION_UNIFORM
    uniform float lastRainToggleTime;
    uniform int lastRainToggleState;
    uniform float rainTransitionSeconds;
#endif

    float _hash12(vec2 p){
        return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123);
    }

    vec2 _hash22(vec2 p){
        return fract(sin(vec2(dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)))) * 43758.5453);
    }

    float rippleField(vec2 p, float t, float scale){
        p *= scale;
        vec2 ip = floor(p);
        float h = 0.0;
        const float RIPPLE_SPEED = 1.4;
        for(int oy=-1; oy<=1; oy++){
            for(int ox=-1; ox<=1; ox++){
                vec2 cell = ip + vec2(ox, oy);
                vec2 center = cell + _hash22(cell);
                vec2 d = p - center;
                float dist = length(d) + 1e-5;
                float cellSeed = _hash12(cell) * 1.31;
                float period = 0.8;
                const int RINGS_PER_DROP = 3;
                const float RING_GAP = 0.20;
                const float RING_WIDTH = 0.025;
                const float RING_BLEND_BOOST = 0.1;
                float lifetime = (float(RINGS_PER_DROP) * RING_GAP) / max(0.0001, RIPPLE_SPEED) + 0.5;
                float fadeIn = min(0.35, lifetime * 0.35);
                float fadeOut = min(0.35, lifetime * 0.35);
                float age = mod(t + cellSeed, period);
                if(age <= lifetime){
                    float envTime = smoothstep(0.0, fadeIn, age) * (1.0 - smoothstep(lifetime - fadeOut, lifetime, age));
                    float ringsSum = 0.0;
                    for(int ri=0; ri<RINGS_PER_DROP; ri++){
                        float radius = age * RIPPLE_SPEED - float(ri) * RING_GAP;
                        if(radius > -RING_WIDTH){
                            float dd = dist - radius;
                            float pulse = exp(-(dd*dd) / (RING_WIDTH * RING_WIDTH));
                            ringsSum += pulse * (1.0 - ringsSum);
                        }
                    }
                    float envDist = exp(-dist * 1.0);
                    float cellContrib = ringsSum * envDist * envTime * 0.9 / (1.0 + dist*2.5) * RING_BLEND_BOOST;
                    h += cellContrib * (1.0 - h);
                }
            }
        }
        return h * 0.35;
    }



vec3 applyRainRipples(in vec3 baseNormal, in vec2 uv, in vec3 worldPos, in float strength, out float outRough){
    float t;
    #if defined LAVA_NOISE || defined SCULK_NOISE
        t = fragmentFrameTime;
    #else
        t = globalTime;
    #endif
    vec2 p = worldPos.xz;
    float sc1 = 3.8;
    float sc2 = 4.8;
    float sc3 = 5.0;
    float h0 = rippleField(p, t, sc1) + 0.35 * rippleField(p + vec2(12.34,45.67), t, sc2) + 0.35 * rippleField(p + vec2(24.68,91.34), t, sc3);
    const float eps = 0.0155;
    float hx = rippleField(p + vec2(eps,0.0), t, sc1) + 0.35 * rippleField(p + vec2(12.34+eps,45.67), t, sc2) + 0.35 * rippleField(p + vec2(24.68+eps,91.34), t, sc3);
    float hy = rippleField(p + vec2(0.0,eps), t, sc1) + 0.35 * rippleField(p + vec2(12.34,45.67+eps), t, sc2) + 0.35 * rippleField(p + vec2(24.68,91.34+eps), t, sc3);
    vec2 grad = vec2((hx-h0)/eps, (hy-h0)/eps);
    float rainMix = smoothstep(RAIN_MIN_DEF, RAIN_MIN_DEF, strength);
#ifdef RAIN_TRANSITION_UNIFORM
    if(rainTransitionSeconds > 0.0){
        float dt = fragmentFrameTime - lastRainToggleTime;
        float tnorm = clamp(dt / rainTransitionSeconds, 0.0, 1.0);
        float transMix = (lastRainToggleState == 1) ? smoothstep(0.0,1.0,tnorm) : (1.0-smoothstep(0.0,1.0,tnorm));
        rainMix = max(rainMix, transMix);
    }
#endif
    grad *= strength * 0.5 * rainMix;

    // Ripples only — directional flow on terrain removed.
    vec3 tng = normalize(TBN[0]);
    vec3 bng = normalize(TBN[1]);
    vec3 nrm = normalize(baseNormal - tng * grad.x - bng * grad.y);
    outRough = max(0.0, abs(h0) * strength * 0.15) * rainMix;
    return normalize(mix(baseNormal, nrm, rainMix));
}

   vec3 applyVerticalFlow(in vec3 baseNormal, in vec3 worldPos, in float strength, inout float outRough){
    float t;
    #if defined LAVA_NOISE || defined SCULK_NOISE
        t = fragmentFrameTime;
    #else
        t = globalTime;
    #endif
    vec3 wN = normalize(TBN[2]);
    float faceU = abs(wN.x) > abs(wN.z) ? worldPos.z : worldPos.x;
    const float FLOW_SPEED_V  = 0.40;
    const float FLOW_SCALE_A  = 1.8;
    const float FLOW_SCALE_B  = 3.6;
    const float FLOW_STRENGTH = 0.22;
    const float FD = 0.018;
    vec2 uvA = vec2(faceU, worldPos.y + t * FLOW_SPEED_V) * FLOW_SCALE_A;
    float hA   = textureLod(noisetex, uvA, 0).z;
    float hAdx = textureLod(noisetex, uvA + vec2(FD, 0.0), 0).z;
    float hAdy = textureLod(noisetex, uvA + vec2(0.0, FD), 0).z;
    vec2 gradA = vec2(hAdx - hA, hAdy - hA) / FD;
    vec2 uvB = vec2(faceU + t * 0.04, worldPos.y + t * FLOW_SPEED_V * 1.3) * FLOW_SCALE_B;
    float hB   = textureLod(noisetex, uvB, 0).z;
    float hBdx = textureLod(noisetex, uvB + vec2(FD, 0.0), 0).z;
    float hBdy = textureLod(noisetex, uvB + vec2(0.0, FD), 0).z;
    vec2 gradB = vec2(hBdx - hB, hBdy - hB) / FD;
    vec2 flowGrad = (gradA * 0.65 + gradB * 0.45) * (FLOW_STRENGTH * strength);
    float rainMix = clamp(strength * 2.0, 0.0, 1.0);
    vec3 faceHoriz;
    if(abs(wN.x) > abs(wN.z)){ faceHoriz = vec3(0.0, 0.0, 1.0); }
    else { faceHoriz = vec3(1.0, 0.0, 0.0); }
    vec3 worldDown = vec3(0.0, -1.0, 0.0);
    vec3 perturbed = normalize(baseNormal + faceHoriz * flowGrad.x - worldDown * abs(flowGrad.y));
    outRough += length(flowGrad) * 0.05 * rainMix;
    return normalize(mix(baseNormal, perturbed, rainMix));
}

    #ifdef LAVA_NOISE
        #include "/lib/surface/lava.glsl"
    #endif

    #if defined ENVIRONMENT_PBR && !defined FORCE_DISABLE_WEATHER
        uniform float isPrecipitationRain;
        #include "/lib/PBR/enviroPBR.glsl"
    #endif

    #include "/lib/lighting/complexShadingForward.glsl"

    void main(){
        dataPBR material;
        getPBR(material, blockId);

        if(blockId == 11100 || blockId == 13005){
            vec2 blockUv = vertexWorldPos.zy * TBN[2].x + vertexWorldPos.xz * TBN[2].y + vertexWorldPos.xy * TBN[2].z;
            if(blockId == 11100){
                #ifdef LAVA_NOISE
                    const float lavaTileSizeInv = 1.0 / LAVA_TILE_SIZE;
                    float lavaNoise = saturate(max(getLavaNoise(blockUv * lavaTileSizeInv) * 3.0, sumOf(material.albedo.rgb)) - 1.0);
                    material.albedo.rgb = floor(material.albedo.rgb * lavaNoise * LAVA_BRIGHTNESS * 32.0) * 0.03125;
                #else
                    material.albedo.rgb *= LAVA_BRIGHTNESS;
                #endif
            }
            else if(blockId == 13005){
                #ifdef SCULK_NOISE
                    float sculkNoise = texelFetch(noisetex, ivec2((blockUv + fragmentFrameTime) * SCULK_TILE_SIZE) & 255, 0).z;
                    material.emissive = min(1.0, material.emissive * squared(squared(sculkNoise) * 4.0) * SCULK_BRIGHTNESS);
                #else
                    material.emissive *= SCULK_BRIGHTNESS;
                #endif
            }
        }

        material.albedo.rgb = toLinear(material.albedo.rgb);

        #if defined ENVIRONMENT_PBR && !defined FORCE_DISABLE_WEATHER
            if(blockId != 11100 && blockId != 12101) enviroPBR(material, TBN[2]);
        #endif

        sceneColOut = complexShadingForward(material).rgb;

        vec3 outNormal = material.normal;
        float roughAdj = 0.0;
        #ifndef FORCE_DISABLE_WEATHER
            const float RAIN_MIN = 0.12;
            if(isEyeInWater == 0 && rainStrength > RAIN_MIN){
                float s = clamp(rainStrength, 0.0, 1.0);
                vec3 worldN = normalize(TBN[2]);
                const float TOP_THRESHOLD = 0.55;
                
                // Include block light (lmCoord.x) so reflections persist under torches/lamps
                float localSky = smoothstep(0.92, 0.995, lmCoord.y);
                float localBlock = smoothstep(0.5, 0.95, lmCoord.x);
                float camSky = smoothstep(0.55, 0.90, eyeBrightFact);
                float lightMix = max(localSky, localBlock) * camSky;
                const float LIGHT_MIN = 0.40;
                
                #if defined ENVIRONMENT_PBR && !defined FORCE_DISABLE_WEATHER
                    if(isPrecipitationRain > 0.5 && worldN.y > TOP_THRESHOLD && lightMix > LIGHT_MIN){
                        outNormal = applyRainRipples(material.normal, texCoord, vertexWorldPos, s * lightMix, roughAdj);
                    } else if(isPrecipitationRain > 0.5 && abs(worldN.y) < TOP_THRESHOLD && lightMix > LIGHT_MIN * 0.5){
                        outNormal = applyVerticalFlow(material.normal, vertexWorldPos, s * lightMix, roughAdj);
                    }
                #else
                    if(worldN.y > TOP_THRESHOLD && lightMix > LIGHT_MIN){
                        outNormal = applyRainRipples(material.normal, texCoord, vertexWorldPos, s * lightMix, roughAdj);
                    } else if(abs(worldN.y) < TOP_THRESHOLD && lightMix > LIGHT_MIN * 0.5){
                        outNormal = applyVerticalFlow(material.normal, vertexWorldPos, s * lightMix, roughAdj);
                    }
                #endif
            }
        #endif

        normalDataOut = outNormal;
        albedoDataOut = material.albedo.rgb;
        materialDataOut = vec3(material.metallic, clamp(material.smoothness + roughAdj, 0.0, 1.0), 0);
    }
#endif