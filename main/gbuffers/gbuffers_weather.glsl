/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// Buffer features: TAA jittering, and direct shading

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    #ifdef FORCE_DISABLE_WEATHER
        void main(){
            gl_Position = vec4(-10);
        }
    #else
        flat out float lmCoordX;
        flat out vec3 blockLightColor;

        out vec2 texCoord;

        #if ANTI_ALIASING == 2
            uniform int frameMod;

        uniform float pixelWidth;
        uniform float pixelHeight;

            #include "/lib/utility/taaJitter.glsl"
        #endif

        #ifdef WEATHER_ANIMATION
            uniform float rainStrength;

            uniform float vertexFrameTime;

            uniform vec3 cameraPosition;

            uniform mat4 gbufferModelView;
            uniform mat4 gbufferModelViewInverse;

            #include "/lib/vertex/weatherWave.glsl"
        #endif

        void main(){
            // Lightmap fix for mods + Colored Lighting support
            {
                ivec2 rawLm = ivec2(gl_MultiTexCoord1.xy);
                int lsShort = rawLm.x;
                int msShort = rawLm.y;
                int red8    = (lsShort >> 0) & 0xFF;
                int green8  = (lsShort >> 8) & 0xFF;
                int blue8   = (msShort >> 4) & 0xFF;
                int alpha4  = (msShort >> 12) & 0xF;
                if (alpha4 == 0xF) {
                    float lum = pow(max(max(red8, green8), blue8) * 0.00392156862745, 1.3);
                    lmCoordX = lightMapCoord(floor(lum * 240.0));
                    blockLightColor = pow(vec3(red8, green8, blue8) * 0.00392156862745, vec3(1.3)) / max(lum, 0.00001);
                } else {
                    lmCoordX = lightMapCoord(float(rawLm.x));
                    blockLightColor = blockLightColorDefault;
                }
            }
            // Get buffer texture coordinates
            texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

            // Get vertex view position
            vec3 vertexViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

            #ifdef WEATHER_ANIMATION
                // Get vertex eye player position
                vec3 vertexEyePlayerPos = mat3(gbufferModelViewInverse) * vertexViewPos;

                // Get vertex feet player position
                vec2 vertexFeetPlayerPosXZ = vertexEyePlayerPos.xz + gbufferModelViewInverse[3].xz;
                // Get vertex world position
                vec2 vertexWorldPosXZ = vertexFeetPlayerPosXZ + cameraPosition.xz;

                // Apply weather wave animation
                if(rainStrength >= 0.005) vertexEyePlayerPos.xz = getWeatherWave(vertexEyePlayerPos, vertexWorldPosXZ);

                // Convert back to vertex view position
                vertexViewPos = mat3(gbufferModelView) * vertexEyePlayerPos;
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
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    #ifdef FORCE_DISABLE_WEATHER
        void main(){
            discard; return;
        }
    #else
        /* RENDERTARGETS: 4 */
        layout(location = 0) out vec4 sceneColOut; // colortex4

        flat in float lmCoordX;
        flat in vec3 blockLightColor;

        in vec2 texCoord;

        uniform float nightVision;
        uniform float lightningFlash;

        uniform sampler2D gtexture;

        #ifndef FORCE_DISABLE_DAY_CYCLE
            uniform float dayCycle;
        #endif

        uniform float twilightPhase;

        #ifdef WORLD_VANILLA_FOG_COLOR
            uniform vec3 fogColor;
        #endif
        
        void main(){
            // Get albedo color
            vec4 albedo = textureLod(gtexture, texCoord, 0);

            // Alpha test, discard and return immediately
            if(albedo.a < ALPHA_THRESHOLD){ discard; return; }

            // Convert to linear space
            albedo.rgb = toLinear(albedo.rgb);

            vec3 totalDiffuse = toLinear(SKY_COLOR_DATA_BLOCK) + toLinear(lmCoordX * blockLightColor) + toLinear(AMBIENT_LIGHTING + nightVision * 0.5);

            totalDiffuse += lightningFlash;

            sceneColOut = vec4(albedo.rgb * totalDiffuse, albedo.a);
        }
    #endif
#endif