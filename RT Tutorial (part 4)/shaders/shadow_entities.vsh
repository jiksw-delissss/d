#version 430 compatibility

#include "/stuff/settings.glsl"

#define IS_AN_ENTITY 1

//data from minecraft / iris
	in vec4 at_midBlock;
	uniform vec3 cameraPosition;
	uniform mat4 gbufferModelViewInverse;
	attribute vec4 mc_Entity;
	uniform float frameTimeCounter;
	uniform mat4 shadowModelViewInverse;
	uniform int renderStage;
	uniform int entityId;
	uniform vec3 skyColor;
	uniform sampler2D gtexture;
	//the 3d texture we are writing voxel data to
	layout (r32ui) uniform uimage3D cimage1;


//data we send to fragment shader
	out vec2 lmcoord;
	out vec2 texcoord;
	out vec4 glcolor;

//included files
	#include "/stuff/local_texture_coords.glsl"
 	#include "/stuff/uv_packing.glsl"

void main() {

	//standard stuff
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	
	//for voxelizing
	#define WHERE_TO_VOXELIZE 2 //[1 2]
	#if WHERE_TO_VOXELIZE == 2
		#include "/stuff/voxelizing.glsl"
	#endif
	
	
	//standard vertex transformation
	gl_Position = ftransform();
}

