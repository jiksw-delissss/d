/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    Developed by Eldeston, presented by FlameRender (C) Studios.

    Copyright (C) 2023 Eldeston | FlameRender (C) Studios License


    By downloading this content you have agreed to the license and its terms of use.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    out vec3 vertexColor;

    uniform vec3 cameraPosition;

    uniform mat4 gbufferModelViewInverse;

    #ifdef WORLD_CURVATURE
        uniform mat4 gbufferModelView;
    #endif

    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;

    void main(){
        // Get vertex color (albedo) for RSM GI
        vertexColor = gl_Color.rgb;

        // Get vertex view position
        vec3 vertexViewPos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
        // Get vertex feet player position
        vec3 vertexFeetPlayerPos = mat3(gbufferModelViewInverse) * vertexViewPos + gbufferModelViewInverse[3].xyz;

        // Get world position
        vec3 vertexWorldPos = vertexFeetPlayerPos + cameraPosition;

        #ifdef WORLD_CURVATURE
            // Apply curvature distortion
            vertexFeetPlayerPos.y -= lengthSquared(vertexFeetPlayerPos.xz) * worldCurvatureInv;

            // Convert back to vertex view position
            vertexViewPos = mat3(gbufferModelView) * vertexFeetPlayerPos + gbufferModelView[3].xyz;
        #endif

        // Transform to shadow space
        vec3 shadowPos = mat3(shadowModelView) * vertexFeetPlayerPos + shadowModelView[3].xyz;
        shadowPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowPos + shadowProjection[3].xyz;

        // Apply shadow distortion
        gl_Position = vec4(shadowPos.xy / (length(shadowPos.xy) + 0.1), shadowPos.z, 1.0);
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec3 shadowColOut; // shadowcolor0

    in vec3 vertexColor;

    void main(){
        // Output albedo color for Distant Horizons RSM GI
        shadowColOut = vertexColor;
    }
#endif