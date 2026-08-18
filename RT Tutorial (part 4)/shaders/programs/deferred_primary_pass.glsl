// MIT License: Do Whatever you want to with this code as long as this line stays in the file. This file contains code Copyright © 2026 timetravelbeard (contact: https://www.patreon.com/timetravelbeard , https://youtube.com/@timetravelbeard3588 , https://discord.gg/S6F4r6K5yU )  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Purpose:
	// Main Defered Pass: 
		// Primary Lighting & Stuff
		// Debug View of voxelized data
		// Composite the defered stuff on top of the Sky and clouds in colortex 0

// Our Settings
	#include "/stuff/settings.glsl"

// Data from Minecraft / Iris
    uniform vec3 skyColor;
	uniform vec3 cameraPosition;
	uniform vec3 shadowLightPosition;

	//space transforms
    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;

// Samplers / Textures / Images
	//shadows
	uniform sampler2D shadowcolor0;
	uniform sampler2D shadowtex0;
	uniform sampler2D shadowtex1;
	//depth
	uniform sampler2D  depthtex0;
	
	//working scene image
    uniform sampler2D colortex0; // scene image
	
	//defered data
    uniform sampler2D colortex1; // albedo
    uniform sampler2D colortex2; // specular tex 
    uniform sampler2D colortex3; // normals tex (in world space) 
    uniform sampler2D colortex4; // defered_data_1_tex; // vec4(lmcoord,ao,height_map);
	uniform sampler2D colortex5; // vec3 normals_face_world

	//the 3d texture we are writing voxel data to
	layout (r32ui) uniform uimage3D cimage1;
	//our 3d image with voxel data as an interpolated sampler
	uniform usampler3D cSampler1;

// Data from Vertex Shader
    in vec2 texcoord;

// Outputs
    /* RENDERTARGETS:0 */
    layout(location = 0) out vec4 color;
	
// Included files 
	#include "/stuff/uv_packing.glsl"
    #include "/stuff/rt/rt.glsl"
    #include "/stuff/space_transforms.glsl"
    #include "/stuff/noise/noise_texture.glsl"
	

void main()
{
    // Load data and unpack
	    vec4 albedo = texture(colortex1, texcoord);
		vec4 specular_tex = texture(colortex2, texcoord);
        vec4 defered_data_1_tex = texture(colortex4, texcoord);
        vec2 lmcoord = defered_data_1_tex.xy;
		vec3 normals_face_world =  texture(colortex5, texcoord).xyz;
		vec3 normals_texture_world =  texture(colortex3, texcoord).xyz;

        #if USE_TEXTURE_NORMALS == 0
            normals_texture_world = normals_face_world;
        #endif
		
		vec3 foot_pos;
		   { //scoped to remove variables from memory as soon as we don't need them anymore
				vec3 position_screen = vec3(texcoord, texture(depthtex0,texcoord).r);
				vec3 position_view = screen_to_view_space(position_screen);
				foot_pos = view_to_foot_space(position_view);
			}

    // Apply our lighting
        vec3 sky_light = lmcoord.y* mix( skyColor, vec3(1.), min(1.,skyColor.r*2.) );
        vec3 block_light = lmcoord.x*vec3(1.,.9,.5);
        
        vec3 lighting = sky_light + block_light;
        
		//diffuse - scattered soft light
        color.rgb = albedo.rgb * lighting;
			
		//specular - shiny things and reflections
		//get sun diresction in the world
		vec3 sun_or_moon_dir_world = normalize(
					view_to_foot_space(shadowLightPosition)
					 #if SOFT_RT_SHADOWS == 1
						+ SUN_WIDTH * (2.*blue_noise().xyz-1.)
					#endif
				);
		
		//trace reflection	
		vec3 view_dir_world;
		   { //scoped to remove variables from memory as soon as we don't need them anymore
				vec3 position_screen = vec3(texcoord, 1.);
				vec3 position_view = screen_to_view_space(position_screen);
				view_dir_world = normalize( view_to_foot_space(position_view) );
			}
		vec3 reflected_ray_angle = normalize( reflect(view_dir_world, normals_texture_world ) + (1.-specular_tex.r) * .9 * (2.*blue_noise().xyz-1.));
		float fresnel = pow( max(0., dot( view_dir_world, reflected_ray_angle)) ,6.);
		float shininess = specular_tex.g +(1.-specular_tex.g)*fresnel;
		if(shininess > 0.001)
		{	
			//reflected_ray_angle = vec3(1.,0.,0.);//Debug
			
			Traced_ray traced_ray = trace_ray(foot_pos+reflected_ray_angle*.001, reflected_ray_angle);
			vec3 reflection_color = (traced_ray.hit_something) ? 
					traced_ray.albedo.rgb 
					: dot(sun_or_moon_dir_world,traced_ray.dir) > 1.- SUN_WIDTH*.00025 ? vec3(1.) : skyColor;
					
			//metals
			if(specular_tex.g>230./255.) reflection_color*=albedo.rgb;
			//add in to scene
			color.rgb  = color.rgb * (1.- shininess) + shininess * reflection_color;
		}
		

    // Add background
        vec4 bg = texture(colortex0, texcoord);

        color.rgb = mix(bg.rgb, color.rgb, albedo.a);
		
		
		
	// Debug Views
	#if VOXELIZED_DEBUG_VIEW == 1
	    // to show voxel range
	    color.r = 1.; 
	    
	    //get voxel map position
	    #define VOXEL_AREA 128 //[32 64 128]
	    #define VOXEL_RADIUS (VOXEL_AREA/2)

	    //get which voxel this is in 2 ways
	    #define VOXEL_POSITION_RECONSTRUCTION_METHOD 2 //[1 2]
	    #if VOXEL_POSITION_RECONSTRUCTION_METHOD == 1
		    //passed from vertex shader
		    ivec3 voxel_pos = ivec3(block_centered_relative_pos+VOXEL_RADIUS);
	    #endif
	    #if VOXEL_POSITION_RECONSTRUCTION_METHOD == 2
		    //reconstructed using foot position & face normals
		    ivec3 voxel_pos = ivec3(foot_pos-normals_face_world*.1+fract(cameraPosition)+VOXEL_RADIUS);
	    #endif
	    
	    //check if in voxel range
	    if( clamp(voxel_pos,0,VOXEL_AREA) == voxel_pos )
	    {
		    //get data, unpack, visualize
		    vec4 bytes = unpackUnorm4x8(texture3D(cSampler1, vec3(voxel_pos)/vec3(VOXEL_AREA)).r);	
		    color.rgb = bytes.rgb;
		    

		    #if VISUALIZED_DATA == 4
			    //handle a block differently based on type of block, and checking it's neighbors
			    //thick grass
			    bool grass = bytes.g > .7;
			    bool thick_grass = grass;
			    
			    if(grass)
			    {
				    vec3 neighbor = vec3(1.,0.,0.);
				    bytes = unpackUnorm4x8(texture3D(cSampler1, vec3(voxel_pos+neighbor)/vec3(VOXEL_AREA)).r);	
				    thick_grass = thick_grass && (bytes.g > .7 || bytes.g < .1);
				    
				    neighbor = vec3(-1.,0.,0.);
				    bytes = unpackUnorm4x8(texture3D(cSampler1, vec3(voxel_pos+neighbor)/vec3(VOXEL_AREA)).r);	
				    thick_grass = thick_grass && (bytes.g > .7 || bytes.g < .1);
				    
				    neighbor = vec3(0.,0,1.);
				    bytes = unpackUnorm4x8(texture3D(cSampler1, vec3(voxel_pos+neighbor)/vec3(VOXEL_AREA)).r);	
				    thick_grass = thick_grass && (bytes.g > .7 || bytes.g < .1);
				    
				    neighbor = vec3(0.,0,-1.);
				    bytes = unpackUnorm4x8(texture3D(cSampler1, vec3(voxel_pos+neighbor)/vec3(VOXEL_AREA)).r);	
				    thick_grass = thick_grass && (bytes.g > .7 || bytes.g < .1);
					    
			    }
			    color.rgb = thick_grass? vec3(0.,1.,0.) : grass? vec3(1.,0.,0.) : vec3(.2);
		    #endif
		    
		    //just making the shadow pass run
		    //you don't have to do this if using the 'shadows.enabled' flag in shader.properties
		    vec3 shadow = texture(shadowtex0, texcoord*100.).rgb;
		    if(texcoord.x < .01 && texcoord.y < .01) color.rgb  = shadow;
		    
		    //visualize world position represented in voxel map
		    #define DEBUG_ALIGHNMENT 0 //[0 1]
		    #if DEBUG_ALIGHNMENT == 1
			    color.rgb  = fract(vec3(voxel_pos 
			    + floor(cameraPosition)
			    )/5.);
		    #endif
	    }//> in voxelizing range
    #endif
    //> VOXELIZED_DEBUG_VIEW == 1

    #if RT_SHADOWS_IN_GBUFFERS == 1
        //setup
			
             
		//get ray starting position
			vec3 ray_starting_pos = foot_pos;

		//trace ray
		//shadow ray
			bool primary_ray_hit = albedo.a>0.001;
			
			if(primary_ray_hit)
			{
				float sun_lighting = dot(normals_face_world,sun_or_moon_dir_world);
				if(sun_lighting>0.01)
				{
					sun_lighting = dot(normals_texture_world,sun_or_moon_dir_world);
					Traced_ray traced_ray = trace_ray(ray_starting_pos+sun_or_moon_dir_world*.001, sun_or_moon_dir_world);
					sun_lighting = (traced_ray.hit_something) ? 0.:sun_lighting;
				}
				color.rgb *= .5+.5*max(0.,sun_lighting);
			}
			
	#endif
	
	//Debug Area
		//color.rgb = fract(view_dir_world.rgb*10.);
		//color.rgb = fract(foot_pos+cameraPosition);
		//color.rgb = normals_face_world;

}


