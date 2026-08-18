// SEUS Renewed - Rain Lens (ported/adapted for SuperDuperVanillaz)
// This file provides `sdv_applyRainDroplets(sceneCol, uv, time, rainStrength)`.

#define RAIN_LENS  

// access to global skylight / underwater flags
uniform float eyeSkylight;
uniform int isEyeInWater;

// Utility: aspect ratio
float sdv_aspect(){ return viewWidth / max(1.0, viewHeight); }

float distratio(vec2 pos, vec2 pos2, float aspectRatio, vec2 texcoord) {
    float xvect = pos.x * aspectRatio - pos2.x * aspectRatio;
    float yvect = pos.y - pos2.y;
    return sqrt(xvect * xvect + yvect * yvect);
}

vec2 noisepattern(vec2 pos) {
    return vec2(abs(fract(sin(dot(pos, vec2(18.9898,28.633))) * 4378.5453)),
                abs(fract(sin(dot(pos.yx, vec2(18.9898,28.633))) * 4378.5453)));
}

float gen_circular_lens(vec2 center, float size, vec2 texcoord, float aspectRatio) {
    float dist = distratio(center, texcoord, aspectRatio, texcoord) / size;
    return exp(-dist * dist);
}

vec3 sdv_applyRainDroplets(in vec3 sceneCol, in vec2 uv, in float time, in float rainStrengthUniform){
    if(rainStrengthUniform <= 0.001) return sceneCol;

    // Skip rain droplets when the player is underwater or not meaningfully exposed to sky.
    if(isEyeInWater == 1) return sceneCol;
    // `eyeSkylight` is smooth(eyeBrightness.y / 240, 15) — near 0 when under terrain.
    // Require a stronger camera skylight to render screen droplets (prevents indoor leaking).
    const float EYE_SKY_MIN = 0.95;
    if(eyeSkylight < EYE_SKY_MIN) return sceneCol;

    const float pi = 3.14159265359;
    // attenuate droplet generation by camera skylight so droplets vanish when under cover
    float exposure = clamp(eyeSkylight, 0.0, 1.0);
    float rainFactor = rainStrengthUniform * exposure;
    if(rainFactor <= 0.001) return sceneCol;

    float rainlens = 0.0;
    const float lifetime = 8.0; // water drop lifetime in seconds
    float ftime = time * 24.0 / lifetime;
    vec2 drop = vec2(0.0, fract(time / 5.0));

    float aspectRatio = sdv_aspect();

#ifdef RAIN_LENS
    float gen = 1.0 - fract((ftime + 0.5) * 0.5);
    vec2 pos = (noisepattern(vec2(-0.94386347 * floor(ftime * 0.5 + 0.25), floor(ftime * 0.5 + 0.25)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.04, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract((ftime + 1.0) * 0.5);
    pos = (noisepattern(vec2(0.9347 * floor(ftime * 0.5 + 0.5), -0.2533282 * floor(ftime * 0.5 + 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.023, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract((ftime + 1.5) * 0.5);
    pos = (noisepattern(vec2(0.785282 * floor(ftime * 0.5 + 0.75), -0.285282 * floor(ftime * 0.5 + 0.75)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.03, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract(ftime * 0.5);
    pos = (noisepattern(vec2(-0.347 * floor(ftime * 0.5), 0.6847 * floor(ftime * 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.05, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract((ftime + 1.0) * 0.5);
    pos = (noisepattern(vec2(0.8514 * floor(ftime * 0.5 + 0.5), -0.456874 * floor(ftime * 0.5 + 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.020, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract((ftime + 1.5) * 0.5);
    pos = (noisepattern(vec2(0.845156 * floor(ftime * 0.5 + 0.75), -0.2457854 * floor(ftime * 0.5 + 0.75)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.033, uv, aspectRatio) * gen * rainFactor;

    gen = 1.0 - fract(ftime * 0.5);
    pos = (noisepattern(vec2(-0.368 * floor(ftime * 0.5), 0.8654 * floor(ftime * 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.05, uv, aspectRatio) * gen * rainFactor * 5.0;

    gen = 1.0 - fract(ftime * 0.5);
    pos = (noisepattern(vec2(-0.458 * floor(ftime * 0.5), 0.7546 * floor(ftime * 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.055, uv, aspectRatio) * gen * rainFactor * 5.0;

    gen = 1.0 - fract((ftime + 1.0) * 0.5);
    pos = (noisepattern(vec2(0.7532 * floor(ftime * 0.5 + 0.5), -0.54275 * floor(ftime * 0.5 + 0.5)))) * 0.8 + 0.1 - drop;
    rainlens += gen_circular_lens(fract(pos), 0.029, uv, aspectRatio) * gen * rainFactor * 5.0;

    // Optional brightness gating omitted (engine-specific). Keep effect proportional to rainFactor.
#endif

    // small fake refract + add rain lens distortion
    vec2 fake_refract = vec2(sin(time * 1.7 + uv.x * 50.0 + uv.y * 25.0), cos(time * 2.5 + uv.y * 100.0 + uv.x * 25.0));
    vec2 Fake_Refract_1 = vec2(sin(time * 1.7 + uv.x * 50.0 + uv.y * 25.0), cos(time + uv.y * 100.0 + uv.x * 25.0));

    vec2 coord = uv + fake_refract * 0.005 + 0.0045 * (rainlens + Fake_Refract_1 * 0.0045);

    // clamp UV to avoid border sampling artifacts
    float eps = 1.0 / max(viewWidth, viewHeight) * 2.0;
    coord = clamp(coord, vec2(eps), vec2(1.0 - eps));

    vec3 color = texture(colortex3, coord).rgb;
    // subtle tint/additions scaled by rainlens
    color += rainlens * vec3(0.06, 0.08, 0.09) * 0.00001 * max(1.0, time);

    // Blend strength: use rainlens (local) and attenuated global rain factor
    float local = clamp(rainlens, 0.0, 1.0);
    float blend = clamp(rainFactor, 0.0, 1.0) * local;

    return mix(sceneCol, color, blend);
}
