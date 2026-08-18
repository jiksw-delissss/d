// KUDA-like wave function - simpler and more efficient
float getCellNoise(in vec2 uv, in float animateTime){
    float waveSpeed = 0.09;
    
    vec2 coord = uv / 10.0;
    
    float noise = texture2D(noisetex, coord * 1.5 + vec2(animateTime / 20.0 * waveSpeed)).x / 1.5;
    noise += texture2D(noisetex, coord * 1.5 - vec2(animateTime / 15.0 * waveSpeed)).x / 1.5;
    noise += texture2D(noisetex, coord * 3.5 + vec2(animateTime / 12.0 * waveSpeed)).x / 3.5;
    noise += texture2D(noisetex, coord * 3.5 - vec2(animateTime / 9.0 * waveSpeed)).x / 3.5;
    noise += texture2D(noisetex, coord * 7.0 + vec2(animateTime / 6.0 * waveSpeed)).x / 7.0;
    noise += texture2D(noisetex, coord * 7.0 - vec2(animateTime / 4.0 * waveSpeed)).x / 7.0;
    
    return (noise / 6.0) * 3.5;
}

#ifndef WAVE_HEIGHT
#define WAVE_HEIGHT 1.5
#endif

// Attenuation for normals used by reflection/parallax sampling.
// Lower values reduce how much waves bend the reflected image.
#ifndef REFLECTION_NORMAL_STRENGTH
#define REFLECTION_NORMAL_STRENGTH 0.75
#endif

vec4 textureSmooth(in sampler2D tex, in vec2 coord)
{
	return texture2D(tex, coord);
}

float AlmostIdentity(in float x, in float m, in float n)
{
	return x;
}

// KUDA-like wave function - maintains SEUS naming for compatibility
float GetWavesSEUS(in vec3 position, in float animateTime) {
  float waveSpeed = 0.09;
  
  vec3 pos = position;
  
  // KUDA-style positional manipulation
  pos.x += sin(pos.z * 2.0 + animateTime * waveSpeed * 25.0) * 0.1;
  pos.z += cos(pos.x * 1.5 + animateTime * waveSpeed * 25.0) * 0.1;
  
  vec2 coord = vec2(pos.xz / 200.0);
  
  float noise = texture2D(noisetex, coord * 1.5 + vec2(animateTime / 20.0 * waveSpeed)).x / 1.5;
  noise += texture2D(noisetex, coord * 1.5 - vec2(animateTime / 15.0 * waveSpeed)).x / 1.5;
  noise += texture2D(noisetex, coord * 3.5 + vec2(animateTime / 12.0 * waveSpeed)).x / 3.5;
  noise += texture2D(noisetex, coord * 3.5 - vec2(animateTime / 9.0 * waveSpeed)).x / 3.5;
  noise += texture2D(noisetex, coord * 7.0 + vec2(animateTime / 6.0 * waveSpeed)).x / 7.0;
  noise += texture2D(noisetex, coord * 7.0 - vec2(animateTime / 4.0 * waveSpeed)).x / 7.0;
  
  return (noise / 6.0) * 3.5;
}

// KUDA-like wave normals
vec3 GetWavesNormalSEUS(in vec3 position, in float animateTime, in float waveHeight) {
    const float sampleDistance = 0.25;
    vec3 p0 = position;

    float center = GetWavesSEUS(p0, animateTime);
    float left = GetWavesSEUS(p0 + vec3(sampleDistance, 0.0, 0.0), animateTime);
    float up = GetWavesSEUS(p0 + vec3(0.0, 0.0, sampleDistance), animateTime);

    vec3 wavesNormal;
    wavesNormal.r = (center - left) * (waveHeight * 2.0 / sampleDistance);
    wavesNormal.g = (center - up) * (waveHeight * 2.0 / sampleDistance);
    wavesNormal.b = 1.0;
    wavesNormal = normalize(wavesNormal);
    return wavesNormal;
}


float getCellNoise(in vec2 uv){
    const float currentSpeed = CURRENT_SPEED * 0.0625;
    float animateTime = fragmentFrameTime * currentSpeed;
    return getCellNoise(uv, animateTime);
}

// Convert height map of water to a normal map (KUDA-like simplified)
vec4 H2NWater(in vec2 uv){
    const float currentSpeed = CURRENT_SPEED * 0.0625;
    const float waterPixel = WATER_BLUR_SIZE * 0.00390625;
    const float waterDepth = WATER_BLUR_SIZE * WATER_DEPTH_SIZE;

    float animateTime = fragmentFrameTime * currentSpeed;

    vec3 pos = vec3(uv.x * 20.0, 0.0, uv.y * 20.0);

    float h = GetWavesSEUS(pos, animateTime);

    vec3 posX = vec3((uv.x + waterPixel) * 20.0, 0.0, uv.y * 20.0);
    vec3 posY = vec3(uv.x * 20.0, 0.0, (uv.y + waterPixel) * 20.0);

    float hx = GetWavesSEUS(posX, animateTime);
    float hy = GetWavesSEUS(posY, animateTime);

    // KUDA-like derivative calculation
    float dx = (h - hx) * 1.5;
    float dy = (h - hy) * 1.5;

    // Normalize the slope before scaling so water normals stay stable
    vec3 waveNormal = normalize(vec3(dx, dy, 1.0));
    const float reflScale = WATER_REFLECTION_NORMAL_SCALE;
    waveNormal.xy *= reflScale;

    return vec4(waveNormal.x, waveNormal.y, waterDepth, h);
}