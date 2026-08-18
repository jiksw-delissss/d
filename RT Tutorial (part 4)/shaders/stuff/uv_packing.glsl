// MIT License: Do Whatever you want to with this code as long as this line stays in the file. This file contains code Copyright © 2025 timetravelbeard (contact: https://www.patreon.com/timetravelbeard , https://youtube.com/@timetravelbeard3588 , https://discord.gg/S6F4r6K5yU )  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#if TEXTURES_IN_RT > 0

	uniform sampler2D atlas_a;
	layout (r32ui) uniform uimage3D c_image4_voxel_scene;

	
	uint pack_uv_buffer(in vec4 uvst, in vec3 normals_face)
	{
		// bitfield insert lets us add data in to a uint however we want to
			// uint integerValue = bitfieldInsert(0u, uint(uvst.s*8191.), 6, 13);
			// integerValue = bitfieldInsert(integerValue, uint(uvst.t*8191.), 19, 13);
			//return integerValue;

		// Priority: we can use some of the bits to prioritise which texture gets saved for each block
			//facing 123456 -3 bits is 8 sides
			//32-3=29  bits left
			vec3 camera_dir = vec3(1.,0.,0.);//debug
			uint facing = uint(4.+4.*dot(normals_face,-camera_dir));
			
		// Texture size
			// 8 sizes is 3 bits 29 -3 is 26 bits left
			//size 8 16 32 64 128 256 512 1028
			ivec2 Atlas_wh = ivec2(textureSize(atlas_a,0));
			uvst.ba*=Atlas_wh;

			uint tex_st =
				uvst.b>1020.?7u:
				 uvst.b>511.?6u:			
				  uvst.b>255.?5u:
				   uvst.b>127.?4u : 
					uvst.b>63.?3u:
					 uvst.b>31?2u:
					  uvst.b>15?1u:
						0u;
						
		// Texture UVs
			//try 13 bits uv per axis, up to 26 available
			ivec2 uv = ivec2( 8191.*uvst.xy);

		//Pack Data
			uint integerValue = bitfieldInsert(0u, facing, 0, 3);
			integerValue = bitfieldInsert(integerValue, tex_st, 3, 3);
			integerValue = bitfieldInsert(integerValue, uv.x, 6, 13);
			integerValue = bitfieldInsert(integerValue, uv.y, 19, 13);
		   
		//Output
			return integerValue;
		
	}
	
	
	vec4 unpack_uv_buffer(in uint integerValue) 
	{ //sets flags, and returns a vec 3 of gba channels
	
		vec4 uvst;
		
		// Bitfield Extract lets us pull data from a uint32 however we want to
			//uvst.x=
			// float(bitfieldExtract(integerValue, 16, 8)) / 8191.0;
		    // uvst.y = float(bitfieldExtract(integerValue, 24, 8)) / 8191.0;
			//  uvst.ba = vec2(float(bitfieldExtract(integerValue, 3, 3)) / 255.0);
				
		// Extract UVs
			uvst.x = float(bitfieldExtract(integerValue, 6, 13)) / 8191.0;
			uvst.y = float(bitfieldExtract(integerValue, 19, 13)) / 8191.0;
			
		// Extract Texture Tile size
			uint tex_st = bitfieldExtract(integerValue, 3, 3);
			vec2 i_Atlas_wh = 1./vec2(textureSize(atlas_a,0));

			uvst.ba = 
				tex_st==7u? 1024.*i_Atlas_wh :
				tex_st==6u? 512.*i_Atlas_wh :
				tex_st==5u? 256.*i_Atlas_wh :
				tex_st==4u? 128.*i_Atlas_wh :
				tex_st==3u? 64.*i_Atlas_wh :
				tex_st==2u? 32.*i_Atlas_wh :
				tex_st==1u? 16.*i_Atlas_wh :
				8.*i_Atlas_wh ;
				
		// Return Data
		return uvst;
		
	}


	//these versions use bitwise operators for the color modifier
	uint pack_uv_buffer_channel_3(in vec3 v)
	{
		v=clamp(1.-v,0.,1.);//invert for atomicmax

		uvec3 rgbu= uvec3(v *15.9) ; 
		uint bits = (rgbu.r) | (rgbu.g << 4) | (rgbu.b << 8);
		
		return bits;//integerValue;
	}

	vec3 unpack_uv_buffer_channel_3(in uint v)
	{
		//invert for atomic max
		return clamp(1.-vec3(v&0xFu,(v>>4)&0xFu,(v>>8)&0xFu )/15. ,0.,1.);
	}

#endif
//> Using Textures in RT