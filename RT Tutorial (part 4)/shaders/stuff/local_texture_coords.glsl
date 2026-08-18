vec4 vlocal_uv_components;//CTMPOMFIX
		vec4 vlocal_uv;//CTMPOMFIX
		attribute vec4 mc_midTexCoord;
		//attribute vec4 mc_midTexCoord;//CTMPOMFIX
		vec2 quad_center;
		void deconstruct_and_localize_uvs()//CTMPOMFIX
		{

		
			//use vertex corners of quad to get local coords and components fir reconstruction
			vec2 atlas_uvs = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
			//standard get center of quad
			quad_center= (gl_TextureMatrix[0] *  mc_midTexCoord).st;
			//get center_relative_uvs
			vec2 center_relative_uvs = atlas_uvs.xy-quad_center.xy;
			
			//per vertex local coords 0.0-1.0
			vlocal_uv.st = 0.5 + 0.5 * sign(center_relative_uvs); 
			
			
			//location of uv 0,0 in texture
			vlocal_uv_components.st  = min(atlas_uvs.xy,quad_center-center_relative_uvs);
			
			//size of quad in atlas
			vlocal_uv_components.pq  =  abs(center_relative_uvs)*2.0;

			//and in frag shader
			//atlas_uv_for_tex_lookup = fract(local_uv.st)*local_uv_components.pq+local_uv_components.st;
		}