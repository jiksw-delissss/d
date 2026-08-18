/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================

    RT Debug View (WIP) -- ported from timetravelbeard's Voxelizing Tutorial.

    Runs after FXAA (composite8), before final.glsl. On the right half of the screen,
    replaces the rasterized image with a raytraced view of whatever got voxelized into
    cimage1 during the shadow pass. Left half is untouched, so you can compare them
    side by side. Not wired into lighting/reflections -- this is only the debug view.

================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

#extension GL_ARB_shader_image_load_store : require
#extension GL_ARB_gpu_shader5 : require

/// -------------------------------- /// Vertex Shader /// -------------------------------- ///

#ifdef VERTEX
    noperspective out vec2 texCoord;

    void main(){
        texCoord = gl_MultiTexCoord0.xy;
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0, 1);
    }
#endif

/// -------------------------------- /// Fragment Shader /// -------------------------------- ///

#ifdef FRAGMENT
    /* RENDERTARGETS: 3 */
    layout(location = 0) out vec3 postColOut; // colortex3

    noperspective in vec2 texCoord;

    uniform sampler2D colortex3;

    #ifdef RAYTRACING_DEBUG_VIEW
        uniform vec3 cameraPosition;
        uniform vec3 skyColor;
        uniform mat4 gbufferProjectionInverse;
        uniform mat4 gbufferModelViewInverse;

        layout(r32ui) uniform uimage3D cimage1;

        #include "/lib/rt/rtTrace.glsl"

        vec3 sdv_screenToView(in vec3 screenPos){
            vec4 clip = vec4(screenPos * 2.0 - 1.0, 1.0);
            vec4 view = gbufferProjectionInverse * clip;
            return view.xyz / view.w;
        }

        vec3 sdv_viewToFoot(in vec3 viewPos){
            return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        }
    #endif

    void main(){
        postColOut = texture(colortex3, texCoord).rgb;

        #ifdef RAYTRACING_DEBUG_VIEW
            // Full-screen voxel RT preview: no split-screen debug overlay.
            vec3 directionFoot = normalize(sdv_viewToFoot(sdv_screenToView(vec3(texCoord, 1.0))));

            TracedRay ray = sdv_traceRay(vec3(0.0), directionFoot);
            if(ray.hitSomething){
                vec3 sunDir = normalize(vec3(0.35, 1.0, 0.25));
                vec3 normal = normalize(ray.normalFace);
                float ndotl = max(0.0, dot(normal, sunDir));
                float shadow = sdv_traceShadow(ray.pos + ray.dir * 0.05, sunDir);
                float lit = 0.14 + shadow * ndotl * 1.2;
                postColOut = ray.albedo.rgb * lit;
            } else {
                postColOut = skyColor;
            }
        #endif
    }
#endif
