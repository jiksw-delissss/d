/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: Buffer settings, retro filter, chromatic aberration, and sharpen filter

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    noperspective out vec2 texCoord;

    void main(){
        // Get buffer texture coordinates
        texCoord = gl_MultiTexCoord0.xy;

        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0, 1);
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    // Final scene color out
    layout(location = 0) out vec3 finalColOut;
// In the FRAGMENT section, add these uniforms near the top:
#ifdef ANTI_ALIASING
    uniform float frameFract;
    uniform sampler2D colortex5; // previous frame buffer
#endif
    /*
    Buffer settings, the compiler will attempt to read the commented lines:

    const int shadowcolor0Format = RGB8;

    const int colortex0Format = R11F_G11F_B10F;
    const int colortex1Format = RGB16_SNORM;
    const int colortex2Format = RGBA8;
    const int colortex3Format = RGB8;
    const int colortex4Format = R11F_G11F_B10F;
    const int colortex5Format = RGBA16F;
    const int colortex6Format = R11F_G11F_B10F;
    */

    // NOTE: Do not disable main HDR and LDR scenes' clear
    // May produce visual artifacts

    // SSAO without normals fix for beacon
    const vec4 colortex1ClearColor = vec4(0, 0, 0, 1);
    // Sky silhoutte fix
    const vec4 colortex4ClearColor = vec4(0, 0, 0, 1);

    // Disable to save performance
    const bool shadowcolor0Clear = false;
    const bool colortex0Clear = false;
    const bool colortex2Clear = false;

    // Needed for temporal filtering
    const bool colortex5Clear = false;

    noperspective in vec2 texCoord;
    uniform sampler2D colortex3;
    uniform sampler2D depthtex0;

    #ifdef PREVIOUS_FRAME
        uniform sampler2D depthtex1;
    #endif
    
    // near and far planes are needed for depth calculations
    uniform float near;
    uniform float far;

    // Weather uniforms used by the droplets effect
    uniform float rainStrength;
    uniform float fragmentFrameTime;

    // Resolution uniforms (always available for post effects)
    uniform float viewWidth;
    uniform float viewHeight;
    
    // Camera uniforms for distance calculation
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    
    #ifdef DISTANT_HORIZONS
        uniform sampler2D dhDepthTex0;
    #endif

    #if (ANTI_ALIASING != 0 && defined SHARPEN_FILTER) || defined CHROMATIC_ABERRATION || defined RETRO_FILTER
        // viewWidth/viewHeight are declared above for post effects
    #endif

    #if ANTI_ALIASING != 0 && defined SHARPEN_FILTER
        // Minecraft-style sharpen filter
        // Adjust this value: 0.1 = subtle, 0.5 = medium, 1.0 = strong
        const float SHARPEN_INTENSITY = 0.5;
        
        vec3 sharpenFilter(in vec3 color, in vec2 uv, in vec2 pixelSize) {
            // Get the average of surrounding pixels in a 3x3 grid
            vec3 sum = vec3(0.0);
            
            // Sample a 3x3 grid
            for(float x = -1.0; x <= 1.0; x += 1.0) {
                for(float y = -1.0; y <= 1.0; y += 1.0) {
                    sum += textureLod(colortex3, uv + vec2(x, y) * pixelSize, 0).rgb;
                }
            }
            
            // Calculate average of the 3x3 grid (9 samples)
            vec3 average = sum / 9.0;
            
            // Sharpen by mixing original with difference from average
            vec3 sharpened = color + (color - average) * SHARPEN_INTENSITY;
            
            // Clamp to prevent overshoot and negative values
            return clamp(sharpened, 0.0, 1.0);
        }
    #endif

    // Include post-process helpers after uniforms
    #include "/lib/post/rain_droplets.glsl"
    #include "/lib/post/cartoon.glsl"
    #include "/lib/post/outline_cartoon.glsl"
    #include "/lib/post/outline.glsl"

    // Previous-frame reprojection not available in this pass; use same UV for prev lookups

    // Calculate cel shading fade distance
    // Fades out after ~8 chunks and completely gone before ~16 chunks
    float calculateCelShadingFade(float depth) {
        // Convert from depth [0,1] to linear distance
        float linearDepth = 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
        
        // Distance thresholds (far values are relative to camera distance)
        const float FADE_START = 32.0;
        const float FADE_END = 64.0;
        
        // Calculate smooth fade (1.0 when close, 0.0 when far)
        float fadeFactor = smoothstep(FADE_START, FADE_END, linearDepth);
        return 1.0 - fadeFactor;
    }

    void main(){
        #if defined CHROMATIC_ABERRATION || (ANTI_ALIASING != 0 && defined SHARPEN_FILTER)
            vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
        #endif

        #ifdef RETRO_FILTER
            const float texCoordScale = 0.5 / MC_RENDER_QUALITY;
            vec2 retroResolution = vec2(viewWidth, viewHeight) * texCoordScale;
            vec2 retroCoord = floor(texCoord * retroResolution) / retroResolution;

            #define texCoord retroCoord
        #endif

        #ifdef CHROMATIC_ABERRATION
            vec2 chromaStrength = ((texCoord - 0.5) * ABERRATION_PIXEL_SIZE) * pixelSize;

            finalColOut = vec3(
                textureLod(colortex3, texCoord - chromaStrength, 0).r,
                textureLod(colortex3, texCoord, 0).g,
                textureLod(colortex3, texCoord + chromaStrength, 0).b
            );
        #else
            finalColOut = textureLod(colortex3, texCoord, 0).rgb;
        #endif

        #if ANTI_ALIASING != 0 && defined SHARPEN_FILTER
            finalColOut = sharpenFilter(finalColOut, texCoord, pixelSize);
        #endif
        
        // ===== Apply cartoon/cel shading style with distance fade =====
#ifdef CARTON_STYLE_ENABLED
    float aspectRatio = viewHeight / viewWidth;
    vec3 cartoonColor = applyCartoonStyle(finalColOut, texCoord, aspectRatio);
    
    // Calculate cel shading fade based on depth distance
    float depth = texture(depthtex0, texCoord).r;
    float celShadeFade = calculateCelShadingFade(depth);
    
    // Blend between cartoon and original based on distance
    finalColOut = mix(finalColOut, cartoonColor, celShadeFade);
    
    // Apply cartoon outlines with optional temporal blending
    // Re-applying outlines here restores entity outlines (matches older look).
    // NOTE: This will overlay outlines after TAA (may cause slight jitter on outlines).
    #if OUTLINES != 0
        // get linear depth
        float depth = texture(depthtex0, texCoord).r;
        ivec2 screenTexelCoord = ivec2(texCoord * vec2(viewWidth, viewHeight));

        // legacy outline mask (depth discontinuities)
        float legacy = getOutline(screenTexelCoord, depth);
        if(legacy > 0.001) {
            finalColOut = mix(finalColOut, vec3(0.0), legacy * clamp(OUTLINE_BRIGHTNESS, 0.0, 1.0));
        }

        // apply cartoon ink overlay (depth-based)
        finalColOut = applyCartoonOutline(finalColOut, depthtex0, texCoord, depth, near, far);
    #endif
#endif
        
        // Apply screen-space rain droplets (refraction + streaks)
        finalColOut = sdv_applyRainDroplets(finalColOut, texCoord, fragmentFrameTime, rainStrength);
    }
#endif