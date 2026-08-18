/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: TAA jittering, simple shading, and dynamic clouds

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    #if defined FORCE_DISABLE_CLOUDS || CLOUD_TYPE != 0
        void main(){
            gl_Position = vec4(-10);
        }
    #else
        out float cloudGradient;

        uniform vec3 cameraPosition;

        uniform mat4 gbufferModelViewInverse;

        #if ANTI_ALIASING == 2
            uniform int frameMod;

            uniform float pixelWidth;
            uniform float pixelHeight;

            #include "/lib/utility/taaJitter.glsl"
        #endif

        void main(){
            // Get vertex view position
            vec3 vertexViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
            // Get vertex feet player position
            vec3 vertexFeetPlayerPos = mat3(gbufferModelViewInverse) * vertexViewPos + gbufferModelViewInverse[3].xyz;

            // Cloud gradiante' *spanish accent*
            cloudGradient = saturate((196.5 - vertexFeetPlayerPos.y - cameraPosition.y) * 0.25);

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
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    #if defined FORCE_DISABLE_CLOUDS || CLOUD_TYPE != 0
        void main(){
            discard; return;
        }
    #else
        /* RENDERTARGETS: 4 */
        layout(location = 0) out vec3 sceneColOut; // colortex4

        in float cloudGradient;

        uniform float nightVision;
        uniform float lightningFlash;

        #ifndef FORCE_DISABLE_DAY_CYCLE
            uniform float dayCycle;
            uniform float twilightPhase;
        #endif

        #ifdef WORLD_VANILLA_FOG_COLOR
            uniform vec3 fogColor;
        #endif

        void main(){
            // Apply simple shading
            vec3 baseLighting = toLinear(nightVision * 0.5 + AMBIENT_LIGHTING) + lightningFlash;
            vec3 skyCol = toLinear(SKY_COLOR_DATA_BLOCK);
            vec3 cloudLight = toLinear(LIGHT_COLOR_DATA_BLOCK0) * squared(cloudGradient);

            // Darken the sky under clouds by reducing the sky contribution
            // as cloudGradient increases. The factor controls how strong
            // the darkening is — lower value = lighter underside.
            // Lower factor for much lighter undersides. Can be tuned (0.0 - 1.0).
            float undersideDarkFactor = 0.15; // tunable: lower = lighter

            // Use a nonlinear falloff so edges remain bright while denser
            // parts get more of the darkening/blend. This preserves sky hue.
            float falloff = pow(saturate(cloudGradient), 1.5);
            float w = clamp(undersideDarkFactor * falloff, 0.0, 1.0);

            // Create a darkened version of the sky while preserving color tint
            vec3 darkenedSky = skyCol * (1.0 - 0.6 * w);

            // Blend the original sky into the darkened sky and add cloud light
            // proportionally. This makes the underside visually blend with the
            // surrounding sky instead of appearing as a flat dark band.
            vec3 blendedSkyUnder = mix(skyCol, darkenedSky + cloudLight * w, w);

            sceneColOut = baseLighting + blendedSkyUnder;
        }
    #endif
#endif