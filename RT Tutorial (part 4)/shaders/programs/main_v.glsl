// Purpose:
	// Main Vertex Shader:
		// puts vertexes on screen
		// optionally voxelizes the scene ( usually done in shadow pass, not here )

// Data from Minecraft / Iris
	uniform sampler2D gtexture;
	in vec4 at_midBlock;
	uniform vec3 cameraPosition;
	uniform mat4 gbufferModelViewInverse;
	attribute vec4 mc_Entity;
	uniform float frameTimeCounter;
	uniform vec3 skyColor;
	attribute vec4 at_tangent;

// Data we are sending to the fragment shader
	out vec2 lmcoord;
	out vec2 texcoord;
	out vec4 glcolor;
	
	out vec3 block_centered_relative_pos;
	out vec3 foot_pos2;
	out vec3 normals_face_world;
	out float material_id;
	out vec4 tangent_world;

	
// Outputs: to Textures / Immages / Data Buffers
	layout (r32ui) uniform uimage3D cimage1;


void main() {

	//standard stuff
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	
	//attributes
	material_id = mc_Entity.x;
	
	//positions
	vec3 view_pos = vec4(gl_ModelViewMatrix * gl_Vertex).xyz;
	vec3 foot_pos = (gbufferModelViewInverse * vec4( view_pos ,1.) ).xyz;
	vec3 world_pos = foot_pos + cameraPosition;
	
	//directions
	tangent_world = vec4((gl_NormalMatrix *at_tangent.rgb),at_tangent.w);
	tangent_world.xyz = normalize( (gbufferModelViewInverse * vec4( tangent_world.xyz ,1.) ).xyz );

	
	//for reconstructing in fragment shader
	foot_pos2 = foot_pos;
	normals_face_world = (gl_NormalMatrix * gl_Normal);
	normals_face_world = normalize( (gbufferModelViewInverse * vec4( normals_face_world ,1.) ).xyz );
	
	//voxel map position
	#define VOXEL_AREA 128 //[32 64 128]
	#define VOXEL_RADIUS (VOXEL_AREA/2)
	block_centered_relative_pos = foot_pos + at_midBlock.xyz/64.0 +fract(cameraPosition);
	ivec3 voxel_pos = ivec3(block_centered_relative_pos + VOXEL_RADIUS);
		
	#define WHERE_TO_VOXELIZE 2 //[1 2]
	#if WHERE_TO_VOXELIZE == 1	
		
		//write voxel data
		if(mod(gl_VertexID,4)==0  //only write for 1 vertex
			&& clamp(voxel_pos,0,VOXEL_AREA) == voxel_pos //and in voxel range
		) //for one vertex per face, write if in range
		{
			//pick data to send
			#if VISUALIZED_DATA == 0
				//visualize color average
				vec4 voxel_data =	vec4(textureLod(gtexture, texcoord,log2(float(textureSize(gtexture, 0).x))).rgb* glcolor.rgb,1.);
			#endif
			#if VISUALIZED_DATA == 1
				//visualize position
				vec4 voxel_data = vec4(fract((block_centered_relative_pos.xyz+floor(cameraPosition))*.05),1.);
			#endif
			#if VISUALIZED_DATA == 2
				//visualize color of one pixel
				vec4 voxel_data =	vec4(textureLod(gtexture, texcoord,0).rgb* glcolor.rgb,1.);
			#endif
			#if VISUALIZED_DATA == 3
				//light value
				vec4 voxel_data =	vec4(at_midBlock.w);
			#endif
			#if VISUALIZED_DATA == 4
				//certain block by id
				vec4 voxel_data =	mc_Entity.x == 10000.? vec4(0.,1.,0.,1.) : mc_Entity.x == 10001.? vec4(0.5,0.5,0.,1.) : vec4(0.2);
			#endif
			
			//visialize player position
			if(frameTimeCounter < 1. && distance(vec3(voxel_pos),vec3(VOXEL_RADIUS))< 3.)
			{
				voxel_data = vec4(0.,0.,1.,1.);
			}
			
			//pack data
			uint integerValue = packUnorm4x8( voxel_data );
			
			//write to 3d image	 //imageStore(  //imageAtomicMax(
			imageAtomicMax( cimage1, voxel_pos, integerValue );	

			
			
		}
	#endif
	
	//standard vertex transform
	gl_Position = ftransform();
}
