/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

#extension GL_ARB_shader_image_load_store : require
#extension GL_ARB_gpu_shader5 : require

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    #ifdef WORLD_LIGHT
        out vec2 texCoord;

        #if defined TERRAIN_ANIMATION || defined WORLD_CURVATURE
            uniform mat4 shadowModelView;
            uniform mat4 shadowModelViewInverse;
        #endif

        #ifdef TERRAIN_ANIMATION
            uniform float vertexFrameTime;

            uniform vec3 cameraPosition;

            attribute vec3 at_midBlock;

            #include "/lib/vertex/waveTerrain.glsl"
        #endif

        attribute vec3 mc_Entity;

        #if defined(RAYTRACING_DEBUG_VIEW) || defined(VOXEL_RT_REFLECTIONS) || defined(VOXEL_RT_LIGHTING)
            #if !(defined TERRAIN_ANIMATION || defined WORLD_CURVATURE)
                uniform mat4 shadowModelViewInverse;
            #endif
            #ifndef TERRAIN_ANIMATION
                uniform vec3 cameraPosition;
                attribute vec3 at_midBlock;
            #endif
            uniform sampler2D gtexture;
            layout(r32ui) uniform uimage3D cimage1;
            #include "/lib/rt/voxelizeWrite.glsl"
        #endif

        void main(){
            // Get buffer texture coordinates
            texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

            vec3 voxelTint = gl_Color.rgb;

            // Get vertex view position
            vec3 vertexShdViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;

            #if defined(RAYTRACING_DEBUG_VIEW) || defined(VOXEL_RT_REFLECTIONS) || defined(VOXEL_RT_LIGHTING)
                // Try the full-face fill first (leaves, glass, ice -- real full-cube
                // shapes). If it rejects the geometry as non-axis-aligned (cross-shaped
                // plants, saplings, flowers), fall back to a single-point corner write
                // so these still show up in RT reflections instead of being invisible.
                if(!sdv_writeVoxelFace(vertexShdViewPos, texCoord, voxelTint)){
                    sdv_writeVoxel(vertexShdViewPos, texCoord, voxelTint);
                }
            #endif

            #if defined TERRAIN_ANIMATION || defined WORLD_CURVATURE
                // Get vertex eye player position
                vec3 vertexShdEyePlayerPos = mat3(shadowModelViewInverse) * vertexShdViewPos;

                // Get vertex feet player position
                vec2 vertexShdFeetPlayerPosXZ = vertexShdEyePlayerPos.xz + shadowModelViewInverse[3].xz;
            #endif

            #ifdef TERRAIN_ANIMATION
                // Apply terrain wave animation
                vertexShdEyePlayerPos = getTerrainWave(vertexShdEyePlayerPos, vertexShdFeetPlayerPosXZ + cameraPosition.xz, at_midBlock.y * 0.015625, mc_Entity.x, lightMapCoord(gl_MultiTexCoord1.y), vertexFrameTime);
            #endif
    
            #ifdef WORLD_CURVATURE
                // Apply curvature distortion
                vertexShdEyePlayerPos.y -= dot(vertexShdFeetPlayerPosXZ, vertexShdFeetPlayerPosXZ) * worldCurvatureInv;
            #endif

            #if defined TERRAIN_ANIMATION || defined WORLD_CURVATURE
                // Convert back to vertex view position
                vertexShdViewPos = mat3(shadowModelView) * vertexShdEyePlayerPos;
            #endif

            // Convert to clip position and output as final position
            // gl_Position = gl_ProjectionMatrix * vertexShdViewPos;
            gl_Position.xyz = getMatScale(mat3(gl_ProjectionMatrix)) * vertexShdViewPos;
            gl_Position.z += gl_ProjectionMatrix[3].z;

            gl_Position.w = 1.0;

            // Apply shadow distortion
            gl_Position.xyz = vec3(gl_Position.xy / (length(gl_Position.xy) + 0.1), gl_Position.z * 0.2);
        }
    #else
        void main(){
            gl_Position = vec4(-10);
        }
    #endif
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    #ifdef WORLD_LIGHT
        /* RENDERTARGETS: 0,1 */
        layout(location = 0) out vec3 shadowColOut;    // shadowcolor0
        layout(location = 1) out vec3 shadowAlbedoOut; // shadowcolor1 = albedo for GI

        in vec2 texCoord;

        uniform sampler2D gtexture;

        void main(){
            vec4 shdAlbedo = textureLod(gtexture, texCoord, 0);
            if(shdAlbedo.a < ALPHA_THRESHOLD){ discard; return; }

            shadowColOut    = vec3(0);
            shadowAlbedoOut = shdAlbedo.rgb;
        }
    #else
        void main(){
            discard; return;
        }
    #endif
#endif