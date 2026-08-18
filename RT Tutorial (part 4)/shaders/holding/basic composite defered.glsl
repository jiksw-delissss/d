#version 430 compatibility


//Data from Minecraft / Iris
    uniform vec3 skyColor;

//Samplers / Textures / Images
    uniform sampler2D colortex0; // scene image
    uniform sampler2D colortex1; // albedo
    uniform sampler2D colortex2; // specular tex 
    uniform sampler2D colortex3; // normals tex (in world space) 
    uniform sampler2D colortex4; // defered_data_1_tex; //lmcoord

//Data from Vertex Shader
    in vec2 texcoord;

//Outputs
    /* RENDERTARGETS:0 */
    layout(location = 0) out vec4 color;


void main()
{
    //load data and unpack
	    vec4 albedo = texture(colortex1, texcoord);
        vec4 defered_data_1_tex = texture(colortex4, texcoord);
        vec2 lmcoord = defered_data_1_tex.xy;

    //apply our lighting
        vec3 sky_light = lmcoord.y* mix( skyColor, vec3(1.), min(1.,skyColor.r*2.) );
        vec3 block_light = lmcoord.x*vec3(1.,.9,.5);
        
        vec3 lighting = sky_light + block_light;
        
        color.rgb = albedo.rgb * lighting;

    //add back ground
        vec4 bg = texture(colortex0, texcoord);

        color.rgb = mix(bg.rgb, color.rgb, albedo.a);
}


