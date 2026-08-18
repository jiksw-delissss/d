#version 430 compatibility

// Settings
    #include "/stuff/settings.glsl"



   

// Uniforms: data from iris & minecraft:
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    uniform vec3 skyColor;
    uniform vec3 sunPosition;
    uniform float centerDepthSmooth;
    uniform bool hideGUI;
    uniform float near,far;
    uniform vec3 shadowLightPosition;

    uniform mat4 gbufferPreviousProjection;
    uniform mat4  gbufferPreviousModelView;
    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;
  
    //specifically our textures and images:
        uniform sampler2D colortex0;
        //the 3d texture we are writing voxel data to
        layout (r32ui) uniform uimage3D cimage1;
	    uniform sampler2D shadowtex0;
        uniform sampler2D depthtex0;


// data from the vertex shader
    in vec2 texcoord;


// Outputs
    /* DRAWBUFFERS:0 */
    layout(location = 0) out vec4 color;


//Global Variables:



// Included files 
	#include "/stuff/uv_packing.glsl"
    #include "/stuff/rt/rt.glsl"
    #include "/stuff/space_transforms.glsl"
    #include "/stuff/noise/noise_texture.glsl"


// Functions:

    // Halton sequence generator
    //concept by John Halton in 1960 (if Google can be trusted)
    vec2 halton(int index, int base1, int base2)
    {
        float result1 = 0.0;
        float f1 = 1.0 / float(base1);
        int i1 = index;
        while (i1 > 0) {
            result1 += f1 * float(mod(float(i1), float(base1)));
            i1 = int(float(i1) / float(base1));
            f1 /= float(base1);
        }

        float result2 = 0.0;
        float f2 = 1.0 / float(base2);
        int i2 = index;
        while (i2 > 0) {
            result2 += f2 * float(mod(float(i2), float(base2)));
            i2 = int(float(i2) / float(base2));
            f2 /= float(base2);
        }

        return vec2(result1, result2);
    }


    float linearize_depth(in float d)
    {
	    // from gl_FragCoord.z to world measurements
	    return 2.0 * near  * far / (far + near - (2.0 * d - 1.0) * (far - near));

    }


    float rand(float n){return fract(sin(n) * 43758.5453123);}

    float rand(vec2 n) { 
	    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
    }
	    
    float noise(vec2 n) {
	    const vec2 d = vec2(0.0, 1.0);
      vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
	    return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
    }







//main function

void main() {
    //load the result of the gbuffers rasterizing to start with
	color = texture(colortex0, texcoord);

    #if RAYTRACING_VIEW > 0
        //we are only ray tracing the right half of the screen
        if(texcoord.x>.5)
        {
            //setup
               	vec3 sun_or_moon_dir_world = normalize(
						view_to_foot_space(shadowLightPosition)
						#if SOFT_RT_SHADOWS == 1
							+ SUN_WIDTH * (2.*blue_noise().xyz-1.)
						#endif
					);
		

            //get ray direction from camera

               vec3 direction_world;
               { //scoped to remove variables from memory as soon as we don't need them anymore
                    vec3 position_screen = vec3(texcoord, 1.);//texture(depthtex0,texcoord).r);//doing direction here, not position
                    vec3 position_view = screen_to_view_space(position_screen);
                    vec3 position_foot = view_to_foot_space(position_view);

                    direction_world = normalize(position_foot );
                }


            //get ray starting position

                 vec3 eye_position = vec3(0.) + direction_world*STUPID_RT_BIAS_IRIS_BUG;//this bias seems to be necesary because of an iris bug. Iris isn'y properly filling the renderStage uniform to let us remove entities like the player from the voxelizing. because of this, many rays will hit the player before leaving the camera, unless we add this bias. This is stupid and should hopefully be fixed in iris
            

            //trace ray

                //trace ray
                Traced_ray traced_ray = trace_ray(eye_position, direction_world);
                // show result on screen
                color.rgb = (traced_ray.hit_something) ? 
					traced_ray.albedo.rgb 
					: dot(sun_or_moon_dir_world,direction_world) > 1.- SUN_WIDTH*.00025 ? vec3(1.) : skyColor;

            //shadow ray
                #if RT_SHADOWS_IN_RT_DEBUG_VIEW == 1
                    bool primary_ray_hit = traced_ray.hit_something; // save this so we can reuse the same ray
                    
                    if(primary_ray_hit)
                    {
                        float sun_lighting = dot(traced_ray.normals_face,sun_or_moon_dir_world);
                        if(sun_lighting>0.01)
                        {
                            traced_ray = trace_ray(traced_ray.pos+sun_or_moon_dir_world*.001, sun_or_moon_dir_world);
                            sun_lighting = (traced_ray.hit_something) ? 0.:sun_lighting;
                        }
                        color.rgb *= (traced_ray.hit_something) ? .5: .5+.5*max(0.,sun_lighting);
                    }
                    //revert ray hit value
                    traced_ray.hit_something = primary_ray_hit;
                #endif
                

        }//> texcoord.x > .5
    #endif

}//> main


