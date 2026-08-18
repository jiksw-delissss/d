// Purpose
	// Main fragment shader:
		// defers data, so we can render the scene more efficiently later, without overdraw
	
// Our Settings
	#include "/stuff/settings.glsl"

// Data from minecraft / iris
    uniform vec3 cameraPosition;
    uniform vec3 skyColor;
    uniform vec3 shadowLightPosition;
	#if IS_AN_ENTITY == 1
		uniform vec4 entityColor;
	#endif

    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;

// Samplers / textures / images
    uniform sampler2D lightmap;
    uniform sampler2D gtexture;
    uniform sampler2D normals;
    uniform sampler2D specular;

    //the 3d texture we are writing voxel data to
    layout (r32ui) uniform uimage3D cimage1;
    //our 3d image with interpolated voxel data
    uniform usampler3D cSampler1;

    //shadows
    uniform sampler2D shadowcolor0;
    uniform sampler2D shadowtex0;
    uniform sampler2D shadowtex1;



// Data we sent from vertex shader
    in vec2 lmcoord;
    in vec2 texcoord;
    in vec4 glcolor;
	
    in vec3 block_centered_relative_pos;
    in vec3 foot_pos2;
    in vec3 normals_face_world;
	in float material_id;
	in vec4 tangent_world;



// Outputs: where we are rendering/sending data to

    /* RENDERTARGETS:1,2,3,4,5 */

    //this replaces fragdata[], you just set this variable to what you want to output
    //texture data
        layout(location = 0) out vec4 albedo_tex;
		const vec4 colortex1ClearColor = vec4( 0.0 , 0.0 , 0.0 , 0.0 );
		layout(location = 1) out vec4 specular_tex;
        layout(location = 2) out vec4 normals_tex;
    //other defered data
        layout(location = 3) out vec4 defered_data_1_tex; // vec4(lmcoord,ao,height_map); 
		layout(location = 4) out vec3 normals_face_world_tex; //normals_face_world
		// Texture Buffer Formats
        /*
			const int colortex3Format = RGBA16F; 
			const int colortex5Format = RGB16F; 
		*/

// Included files 
    //#include "/stuff/rt/rt.glsl"
    //#include "/stuff/space_transforms.glsl"
    //#include "/stuff/noise/noise_texture.glsl"



void main() {

    //defer texture data
        //albedo
	    albedo_tex = texture(gtexture, texcoord);
	    albedo_tex.rgb*=glcolor.rgb;
		#if IS_AN_ENTITY == 1
			albedo_tex.rgb = mix(albedo_tex.rgb, entityColor.rgb, entityColor.a);
		#endif

        if(albedo_tex.a < 0.1) discard;
	       
        //specular
        specular_tex = texture(specular, texcoord); 
        specular_tex.a = fract(specular_tex.a);//decode alpha of 1.0 as 0 emission
		
		//intergrated pbr
		if( abs(material_id - 1.) < .5 ) specular_tex = vec4(1.,.02,1.,0.); //water
		#if IRON_MIRRORS == 1
			if( abs(material_id - 2.) < .5 ) specular_tex = vec4(1.,1.,1.,0.); //iron
        #endif
		
        //normals
        normals_tex = texture(normals, texcoord); 
		float ao = normals_tex.b;
		float height_map = normals_tex.a;
		normals_tex.xy=normals_tex.xy*2.-1.;
		normals_tex.z = sqrt(1.0-dot(normals_tex.xy, normals_tex.xy)); //Reconstruct Z
		
		//convert to world space
		vec3 tangent2 = normalize(cross(tangent_world.rgb,normals_face_world.xyz)*tangent_world.w);
		mat3 tbn_matrix = mat3(tangent_world.xyz, tangent2.xyz, normals_face_world.xyz);
		normals_tex.xyz = normalize(tbn_matrix * normals_tex.xyz); //Rotate by TBN matrix 


    //defer other data we want
        defered_data_1_tex = vec4(lmcoord,ao,height_map);
		normals_face_world_tex = normals_face_world;
		
	// Debug Area
		//specular_tex = vec4(1.,0.,0.,1.);//debug
		
}//> main
