// < Noise

uniform sampler2D blue_noise_tex;
float blue_noise_100()
{
	return texelFetch(blue_noise_tex, ivec2(gl_FragCoord.xy/100)%64,0).r;
}
vec4 blue_noise()
{
	return texelFetch(blue_noise_tex, ivec2(gl_FragCoord.xy)%64,0);
}
// > Noise >
