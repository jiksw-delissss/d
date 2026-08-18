/*
	This code is from the VOXELIZING TUTORIAL by timetravelbeard
		learn more at the links below:
			https://www.patreon.com/timetravelbeard
			https://youtube.com/@timetravelbeard3588
			https://discord.gg/S6F4r6K5yU 
			
		if you use this code as is, please leave this header. feel free to use this code in any shaders.
*/
	
	//positions
	vec3 shadow_view_pos = vec4(gl_ModelViewMatrix * gl_Vertex).xyz;
	vec3 foot_pos = (shadowModelViewInverse * vec4( shadow_view_pos ,1.) ).xyz;
	vec3 world_pos = foot_pos + cameraPosition;


	//voxel map position
	#define VOXEL_AREA 128 //[32 64 128]
	#define VOXEL_RADIUS (VOXEL_AREA/2)
    
    #if IS_AN_ENTITY == 1
        vec3 block_centered_relative_pos = foot_pos +fract(cameraPosition); //midblock is broken for entities, so don'y use it here
    #else
    	vec3 block_centered_relative_pos = foot_pos + at_midBlock.xyz/64.0 +fract(cameraPosition);
    #endif

	ivec3 voxel_pos = ivec3(block_centered_relative_pos + VOXEL_RADIUS);


	//write voxel data
	if(
		#if IS_AN_ENTITY == 1
			entityId != 1
		#else
			!(renderStage == MC_RENDER_STAGE_ENTITIES && entityId == 1)
		#endif
        && mod(gl_VertexID,4)==0  //only write for 1 vertex
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
		#if VISUALIZED_DATA == 5
			//visualize color average
			vec4 voxel_data =	vec4(textureLod(gtexture, texcoord,log2(float(textureSize(gtexture, 0).x))).rgb* glcolor.rgb,1.);
            //lighting
            voxel_data.rgb = clamp( voxel_data.rgb * (max(at_midBlock.w,lmcoord.x)*vec3(1.,.9,.7)+mix(skyColor,vec3(1.),min(1.,skyColor.r*2.)) *lmcoord.y), 0.,1.);
		#endif
		//visialize player position
		if(frameTimeCounter < 1. && distance(vec3(voxel_pos),vec3(VOXEL_RADIUS))< 3.)
		{
			voxel_data = vec4(0.,0.,1.,1.);
		}
		
		//pack data
		uint integerValue = packUnorm4x8( voxel_data );
		
		//write to 3d image	 
		//          //imageStore(  //imageAtomicMax(   are some options for writing, look up on khronos.org (opengl documentation)
		imageAtomicMax( cimage1, voxel_pos, integerValue );	
			
				
				
		#if TEXTURES_IN_RT > 0
			deconstruct_and_localize_uvs();
			
			ivec3 buffer_channel_offset = ivec3(0,0,VOXEL_AREA);//texture uvs
			vec3 normals_face = vec3(0.);
			integerValue =  pack_uv_buffer(
				#if USE_VX_UV_BUFFER == 1
					vec4(quad_center,vlocal_uv_components.ba)
				#else
					vlocal_uv_components
				#endif
				
				, normals_face.xyz);
				
			//write UVs			
			imageAtomicMax( c_image4_voxel_scene, voxel_pos+buffer_channel_offset, integerValue );	
			
			//Write glcolor
			integerValue = pack_uv_buffer_channel_3(gl_Color.rgb);
			imageAtomicMax( c_image4_voxel_scene, voxel_pos
				+ivec3(0,VOXEL_AREA,VOXEL_AREA)//glcolor (channel 3)
				, integerValue );	
		#endif	
				
	}//> voxelizing this vertex
