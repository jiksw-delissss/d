// Backwards-compatible wrapper: older shaders call the function without `puddleBlend`.
// Provide an overload that forwards to the newer implementation with `puddleBlend = 0.0`.

// Forward-declare the full overload to avoid forward-reference/overload resolution
// issues on some GLSL compilers/drivers.
vec3 complexShadingDeferred(in vec3 sceneCol, in vec3 screenPos, in vec3 viewPos, in vec3 normal, in vec3 albedo, in vec3 dither, in float viewDotInvSqrt, in float metallic, in float smoothness, in float puddleBlend, in bool realSky);
vec3 complexShadingDeferred(in vec3 sceneCol, in vec3 screenPos, in vec3 viewPos, in vec3 normal, in vec3 albedo, in vec3 dither, in float viewDotInvSqrt, in float metallic, in float smoothness, in bool realSky){
    return complexShadingDeferred(sceneCol, screenPos, viewPos, normal, albedo, dither, viewDotInvSqrt, metallic, smoothness, 0.0, realSky);
}

// Cel shading for deferred lighting - unique name to avoid conflicts
float cartoon_celShadeLighting(float NdotL, int steps) {
    #ifdef CARTON_STYLE_ENABLED
        float s = float(steps);
        float x = clamp(NdotL, 0.0, 1.0) * s;
        float band = floor(x);
        float frac = x - band;
        float knee = float(CEL_THRESHOLD) * 0.006;
        float t = smoothstep(0.0, knee, frac) * smoothstep(knee * 2.0, knee, frac);
        return (band + t) / s + (frac / s) * 0.25;
    #else
        return NdotL;
    #endif
}

// Reflection blur helper: multi-tap Poisson/Gaussian style sampling for high-quality
// screen-space reflection blurring. Use `colortex4` (current frame) or `colortex5`
// (previous frame) as the `sceneTex` argument.
const vec2 reflectionPoissonDisk[8] = vec2[8](
    vec2(-0.94201624, -0.39906216),
    vec2(0.94558609, -0.76890725),
    vec2(-0.094184101, -0.92938870),
    vec2(0.34495938, 0.29387760),
    vec2(-0.91588581, 0.45771432),
    vec2(-0.81544232, -0.87912464),
    vec2(-0.38277543, 0.27676845),
    vec2(0.97484398, 0.75648379)
);

vec3 sampleReflectionBlur(sampler2D sceneTex, vec2 uv, float roughness){
    // roughness: 0.0 = perfectly smooth (sharp), 1.0 = very rough (max blur)
    float r = clamp(roughness, 0.0, 1.0);

    // Even very small roughness should produce a visible blur at high resolutions,
    // so enforce a small minimum effective roughness.
    float minBlur = 0.08; // tune this to control minimum blur strength
    float effR = max(r, minBlur);

    // Radius in pixels (tunable): small for subtle blur, larger for rough surfaces
    float maxRadius = 12.0; // increased for more visible blur on large displays
    float radius = mix(2.0, maxRadius, pow(effR, 0.75));

    // Weigh center modestly to allow blur to show; distribute remainder across taps
    float wCenter = 0.22;
    float wSide = (1.0 - wCenter) / 8.0;

    vec3 col = texture(sceneTex, uv).rgb * wCenter;
    for(int i = 0; i < 8; ++i){
        // Convert pixel offset to UV offset using view dimensions for consistent scaling
        vec2 off = reflectionPoissonDisk[i] * radius / vec2(viewWidth, viewHeight);
        col += texture(sceneTex, uv + off).rgb * wSide;
    }

    return col;
}

// Screen-space reflection occlusion test: march along the reflected view
// direction in view-space, project samples to screen and compare against the
// depth buffer. If an occluder is found between the surface and the sky along
// the reflected ray, consider the sky occluded.
// Guarded by `USE_REFLECTION_OCCLUSION` so it's optional and drop-in safe.
#ifdef USE_REFLECTION_OCCLUSION
bool isReflectionSkyOccluded(in vec3 startViewPos, in vec3 dir){
    vec3 d = normalize(dir);
    // How far to march (tunable). Use borderFar which is used elsewhere.
    float maxDist = borderFar;
    // Number of steps (tunable): 6..12 is a good compromise.
    const int STEPS = 8;
    float step = maxDist / float(STEPS);
    for(int i = 1; i <= STEPS; ++i){
        float dist = step * float(i);
        vec3 samplePos = startViewPos + d * dist;
        vec3 sp = getScreenPos(gbufferProjection, samplePos);
        if(sp.x < 0.0 || sp.x > 1.0 || sp.y < 0.0 || sp.y > 1.0) continue;
        float sceneD = getDepthTex(sp.xy);
        // sp.z is the view-space depth projected; compare with scene depth.
        // small epsilon to avoid self-intersection
        if(sceneD < sp.z - 0.002) return true;
    }
    return false;
}
#endif

// `puddleBlend` is passed via the G-buffer material.z channel (0..1).
// When >0 it indicates puddle/ripple strength; we warp reflection sampling accordingly.
vec3 complexShadingDeferred(in vec3 sceneCol, in vec3 screenPos, in vec3 viewPos, in vec3 normal, in vec3 albedo, in vec3 dither, in float viewDotInvSqrt, in float metallic, in float smoothness, in float puddleBlend, in bool realSky){
    vec3 noiseUnitVector = generateUnitVector(dither.xy);

    // ── World-Space (View-Space) Global Illumination ─────────────────────────
    #ifdef SSGI
    {
        vec3 indirect = vec3(0.0);
        float totalWeight = 0.0;
        
        ivec2 screenTexelCoord = ivec2(gl_FragCoord.xy);
        
        // Fetch blue noise and rotate it per frame for temporal filtering
        float dither = texelFetch(noisetex, screenTexelCoord & 255, 0).x;
        float angle = dither * 6.2831853 + fragmentFrameTime * 1.5;
        float s = sin(angle), c = cos(angle);
        
        const int RAYS = 8;
        const float GOLDEN_ANGLE = 2.39996323;
        
        for(int i = 0; i < RAYS; i++) {
            // Fibonacci spiral for perfectly uniform hemisphere distribution
            float r = sqrt((float(i) + 0.5) / float(RAYS));
            float theta = float(i) * GOLDEN_ANGLE + angle;
            vec2 disk = vec2(cos(theta), sin(theta)) * r;
            
            // Convert to cosine-weighted hemisphere direction
            vec3 localDir = vec3(disk.x, disk.y, sqrt(max(0.0, 1.0 - dot(disk, disk))));
            
            // Align to surface normal (TBN matrix)
            vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
            vec3 tangent = normalize(cross(up, normal));
            vec3 bitangent = cross(normal, tangent);
            vec3 rayDir = normalize(tangent * localDir.x + bitangent * localDir.y + normal * localDir.z);
            
            // Offset origin to prevent self-intersection
            vec3 rayPos = viewPos + normal * 0.1;
            
            float stepSize = 0.3;
            bool hit = false;
            
            // 16 steps per ray = 256 total iterations (good balance of perf and quality)
            for(int j = 0; j < 4; j++) {
                rayPos += rayDir * stepSize;
                
                vec4 clipPos = gbufferProjection * vec4(rayPos, 1.0);
                if(clipPos.w <= 0.0) break;
                
                vec3 ndc = clipPos.xyz / clipPos.w;
                vec2 uv = ndc.xy * 0.5 + 0.5;
                
                if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || ndc.z >= 1.0) break;
                
                float sampledDepth = textureLod(depthtex0, uv, 0).x;
                vec3 hitViewPos = getViewPos(gbufferProjectionInverse, vec3(uv, sampledDepth));
                
                // Correct view-space Z comparison
                // rayPos.z and hitViewPos.z are negative. Ray is behind surface if rayPos.z < hitViewPos.z
                if(rayPos.z < hitViewPos.z && rayPos.z > hitViewPos.z - 1.0) { // 1.0 block thickness
                    vec3 hitCol = textureLod(colortex4, uv, 0).rgb;
                    
                        // Clamp and tone-map bright samples to reduce fireflies/overexposure
                        hitCol = min(hitCol, vec3(4.0));
                        // Simple Reinhard tone-mapping to compress HDR highlights
                        hitCol = hitCol / (1.0 + hitCol);
                    
                    float dist = length(rayPos - viewPos);
                    // Physical quadratic light falloff
                    float falloff = 1.0 / (1.0 + dist * dist * 0.05);
                    
                    indirect += hitCol * falloff;
                    totalWeight += 1.0;
                    hit = true;
                    break;
                }
                
                // Increase step size to cover more distance efficiently
                stepSize *= 1.1;
                if(length(rayPos - viewPos) > 20.0) break; // Max trace distance
            }
            
            if(!hit) {
                // Ray missed geometry and hit the sky — apply ambient sky bounce
                indirect += skyCol * 0.3; 
                totalWeight += 1.0;
            }
        }
        
        if(totalWeight > 0.0) {
            indirect /= totalWeight;
            // Modulate GI by surface albedo and strongly boost intensity
            sceneCol += albedo * indirect * 4.0; 
        }
    }
    #endif
    // ─────────────────────────────────────────────────────────────────────────

    // If smoothness is 0, return immediately
    if(smoothness < 0.005) return sceneCol;

    #ifdef ROUGH_REFLECTIONS
        // Rough the normals with noise
        normal = generateCosineVector(normal, noiseUnitVector * (squared(1.0 - smoothness) * 0.5));
    #endif

    vec3 nViewPos = viewPos * viewDotInvSqrt;

    // Get reflected view direction
    // reflect(direction, normal) = direction - 2.0 * dot(normal, direction) * normal
    float NV = dot(normal, -nViewPos);
    vec3 reflectViewDir = nViewPos + (2.0 * NV) * normal;

    

    // Calculate SSR and sky reflections
    // Prepare reflection color and flag whether it comes from the sky
    vec3 reflectCol = vec3(0.0);
    bool reflectIsSky = false;

    // Optional: sun / shadow visibility test. If you enable `USE_SUN_SHADOW_TEST`
    // and provide the uniforms below, the shader will reduce/disable sun
    // highlights when the surface is shadowed from the sun (prevents bright
    // sun/moon glints on water when the point is in shadow).
    // Required uniforms when enabled:
    //  - uniform mat4 viewToWorld;        // converts view-space pos -> world-space
    //  - uniform mat4 shadowMatrix;      // light projection matrix for shadow map
    //  - uniform sampler2DShadow shadowMap;
    //  - uniform vec3 sunDirectionWorld; // normalized sun direction in world space
    #ifdef USE_SUN_SHADOW_TEST
        vec3 worldPos = (viewToWorld * vec4(viewPos, 1.0)).xyz;
        vec4 shadowCoord = shadowMatrix * vec4(worldPos, 1.0);
        shadowCoord /= shadowCoord.w;
        float sunVisibility = 1.0;
        // Sample shadow map if inside light frustum
        if(shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0){
            sunVisibility = texture(shadowMap, shadowCoord.xyz);
        }
    #endif

    // Optional: lightmap-based sky visibility test. If `USE_LIGHTMAP` is
    // defined, the shader will sample a `lightmap` texture (screen-space or
    // packed light texture provided by the engine) at `screenPos.xy` and use
    // it to attenuate sky/sun reflections when the surface is shadowed.
    // Provide a `uniform sampler2D lightmap;` from the renderer when enabling.
    #ifdef USE_LIGHTMAP
        float lightmapVis = texture(lightmap, screenPos.xy).r;
        // remap/gamma (if your lightmap is HDR or encoded, adjust accordingly)
        lightmapVis = pow(lightmapVis, 1.0);
    #endif

    vec3 rtReflection = vec3(0.0);
    vec3 ssrReflection = vec3(0.0);
    bool rtReflectionValid = false;
    bool ssrReflectionValid = false;
    bool rtIsSky = false;
    bool ssrIsSky = false;

    #ifdef VOXEL_RT_REFLECTIONS
        vec3 reflectDirN = normalize(reflectViewDir);
        vec3 footPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 reflectDirFoot = normalize(mat3(gbufferModelViewInverse) * reflectDirN);

        TracedRay rtHit = sdv_traceReflection(footPos, reflectDirFoot);

        if(rtHit.hitSomething){
            rtReflection = rtHit.albedo.rgb;
            rtReflection = rtReflection / (1.0 + rtReflection);
            rtReflection = min(rtReflection, vec3(1.5));

            float hitDist = length(rtHit.pos - footPos);
            float falloff = 1.0 / (1.0 + hitDist * hitDist * 0.1);
            rtReflection *= falloff;
            rtReflectionValid = true;
            rtIsSky = false;
        } else {
            bool reflLooksUp = reflectDirN.y > -0.5;
            if(reflLooksUp){
                vec3 skySample = getSkyReflection(reflectDirN);

                #ifdef USE_SUN_SHADOW_TEST
                    float sunAlign = max(0.0, dot(reflectDirN, normalize(sunDirectionWorld)));
                    if(sunAlign > 0.96){
                        skySample *= sunVisibility;
                    }
                #endif

                // Sky fallback is NOT a valid RT hit. This allows SSR to still
                // activate for nearby screen-space reflections and keeps RT as the
                // authoritative source only when it actually hit voxel geometry.
                rtReflection = skySample * smoothness;
                rtReflection = rtReflection / (1.0 + rtReflection);
                rtIsSky = true;
            }
        }
    #endif

    #ifdef SSR
        vec3 SSRCoord = rayTraceScene(screenPos, viewPos, reflectViewDir, dither.z);

        if(SSRCoord.z < 0.5){
            vec3 SSRFar = rayTraceScene(screenPos, viewPos, reflectViewDir * borderFar, dither.z);
            if(SSRFar.z >= 0.5) SSRCoord = SSRFar;
        }

        if(SSRCoord.z < 0.5){
            vec3 reflDirN = normalize(reflectViewDir);
            bool reflLooksUp = reflDirN.y > -0.5;
            if(reflLooksUp){
                vec3 skySample = getSkyReflection(reflDirN);

#ifdef USE_REFLECTION_OCCLUSION
                bool occ = isReflectionSkyOccluded(viewPos, reflectViewDir);
                if(occ){
                    skySample = vec3(0.0);
                }
#endif

                #ifdef USE_SUN_SHADOW_TEST
                    float sunAlign = max(0.0, dot(reflDirN, normalize(sunDirectionWorld)));
                    if(sunAlign > 0.96){
                        skySample *= sunVisibility;
                    }
                #endif

                ssrReflection = skySample * smoothness;
                ssrReflection = ssrReflection / (1.0 + ssrReflection);
                ssrReflectionValid = true;
                ssrIsSky = true;
            }
        } else {
            vec2 hitUV = SSRCoord.xy / vec2(viewWidth, viewHeight);
            float hitDist = length(hitUV - clamp(screenPos.xy, vec2(0.0), vec2(1.0)));
            if(hitDist >= 0.0025 || rtReflectionValid){
                #ifdef PREVIOUS_FRAME
                    ivec2 prevPix = ivec2(getPrevScreenCoord(SSRCoord.xy * vec2(pixelWidth, pixelHeight)) * vec2(viewWidth, viewHeight));
                    vec2 texUV = (vec2(prevPix) + 0.5) / vec2(viewWidth, viewHeight);
                    ssrReflection = sampleReflectionBlur(colortex5, texUV, 1.0 - smoothness);
                #else
                    vec2 texUV = hitUV;
                    ssrReflection = sampleReflectionBlur(colortex4, texUV, 1.0 - smoothness);
                #endif
                ssrReflection = min(ssrReflection, vec3(1.5));
                ssrReflectionValid = true;
                ssrIsSky = false;
            }
        }

        // Keep a nearby fallback even when RT is valid; this is what makes SSR feel
        // layered and blended with RT instead of being hidden behind the RT pass.
        if(smoothness > 0.05 && !ssrReflectionValid){
            vec2 fallbackUV = clamp(screenPos.xy + reflectViewDir.xy * 0.06, vec2(0.0), vec2(1.0));
            ssrReflection = sampleReflectionBlur(colortex4, fallbackUV, 1.0 - smoothness);
            ssrReflection = min(ssrReflection, vec3(1.5));
            ssrReflectionValid = true;
            ssrIsSky = false;
        }
    #endif

    if(rtReflectionValid){
        reflectCol = rtReflection;
        reflectIsSky = rtIsSky;
    } else if(ssrReflectionValid){
        reflectCol = ssrReflection;
        reflectIsSky = ssrIsSky;
    } else if(!realSky){
        reflectCol = vec3(0.0);
        reflectIsSky = false;
    } else {
        reflectCol = getSkyReflection(reflectViewDir);
        reflectIsSky = true;
    }

    // If this pixel has puddle ripples, apply a small animated screen-space warp to reflection sampling
    if(puddleBlend > 0.01){
        vec2 uv = screenPos.xy;
        float t = fragmentFrameTime;
        // direction + noise-based magnitude for organic motion
        vec2 rippleDir = vec2(sin(uv.x * 120.0 + t * 4.0), cos(uv.y * 120.0 + t * 3.5));
        float n = texture(noisetex, uv * 4.0 + t * 0.05).x * 2.0 - 1.0;
        float mag = clamp(puddleBlend * 0.035 * (0.5 + 0.5 * n), 0.0, 0.09);
        vec2 sampleUV = uv + rippleDir * mag;
        if(reflectIsSky){
            // For sky reflections, perturb the reflection direction and sample the sky.
            vec3 pert = normalize(reflectViewDir + vec3(rippleDir * mag * 0.5, mag * 0.08));
            reflectCol = getSkyReflection(pert);
        } else {
            // Sample the scene buffer using the high-quality blur helper to get a warped reflection color
            reflectCol = sampleReflectionBlur(colortex4, sampleUV, 1.0 - smoothness);
        }
    }

    // Modified version of BSL's reflection PBR calculation
    // vec3 fresnel = (F0 + (1.0 - F0) * cosTheta) * smoothness
    // Fresnel calculation derived and optimized from this equation
    float smoothCosTheta = NV > 0 ? exp2(-9.28 * NV) * smoothness : smoothness;
    float oneMinusCosTheta = smoothness - smoothCosTheta;

    if(metallic <= 0.9) return sceneCol + reflectCol * (smoothCosTheta + metallic * oneMinusCosTheta);
    return sceneCol + reflectCol * (smoothCosTheta + albedo * oneMinusCosTheta);
}