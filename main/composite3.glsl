/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: DOF blur

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    #ifdef DOF
        flat out float fovMult;

        noperspective out vec2 texCoord;

        uniform mat4 gbufferProjection;
    #endif

    void main(){
        #ifdef DOF
            // Get buffer texture coordinates
            texCoord = gl_MultiTexCoord0.xy;

            fovMult = gbufferProjection[1].y * 0.04549628; // 0.72794047 * 0.0625
        #endif

        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0, 1);
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    /* RENDERTARGETS: 4 */
    layout(location = 0) out vec3 sceneColOut; // colortex4

    uniform sampler2D colortex4;

    #ifdef DOF
        flat in float fovMult;

        noperspective in vec2 texCoord;

        uniform float viewWidth;
        uniform float viewHeight;
        uniform float centerDepthSmooth;

        uniform sampler2D depthtex1;
    #endif

    void main(){
        // Screen texel coordinates
        ivec2 screenTexelCoord = ivec2(gl_FragCoord.xy);

        #ifdef DOF
            // Declare and get positions
            float centerDepth = texture(depthtex1, texCoord).x;

            // Return immediately if player hand
            if(centerDepth <= 0.56){
                sceneColOut = texelFetch(colortex4, screenTexelCoord, 0).rgb;
                return;
            }
            
            // CoC calculation by Capt Tatsu from BSL (auto focus using centerDepthSmooth)
            float CoC = max(0.0, abs(centerDepth - centerDepthSmooth) * DOF_STRENGTH - 0.01);
            CoC = CoC * inversesqrt(CoC * CoC + 0.1);

            // Multi-radius sampling with smooth falloff (like GI debug)
            vec3 dofColor = vec3(0.0);
            float dofWeight = 0.0;

            float maxRadius = min(viewWidth, viewHeight) * fovMult * CoC * 0.5;
            
            const int RINGS = 2;
            const int STEPS = 16;
            
    for(int ring = 1; ring <= RINGS; ring++) {
        float radius = mix(maxRadius * 0.5, maxRadius, float(ring) / float(RINGS));  // Use CoC-based radius
        float ringWeight = exp(-float(ring) * 0.25);  // Slower decay for more far-sample contribution
                
                for(int i = 0; i < STEPS; i++) {
                    vec2 off = vec2(
                        cos(i * 6.283 / float(STEPS) + float(ring) * 0.5),
                        sin(i * 6.283 / float(STEPS) + float(ring) * 0.5)
                    ) * radius / vec2(viewWidth, viewHeight);

                    vec2 uv = texCoord + off;
                    
                    if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;

                    float d = texture(depthtex1, uv).x;
                    if(d <= 0.56) continue;

                    // Depth-aware weighting: softer falloff for smoother blending
                    float depthDiff = abs(centerDepth - d);
                    float depthWeight = exp(-depthDiff * 15.0);
                    
                    vec3 hit = texture(colortex4, uv).rgb;
                    float weight = ringWeight * depthWeight;
                    
                    dofColor += hit * weight;
                    dofWeight += weight;
                }
            }

            if(dofWeight > 0.0) {
                dofColor /= dofWeight;
            } else {
                dofColor = texelFetch(colortex4, screenTexelCoord, 0).rgb;
            }

            sceneColOut = dofColor;
        #else
            // Get scene color
            sceneColOut = texelFetch(colortex4, screenTexelCoord, 0).rgb;
        #endif
    }
#endif