// ============================================================================
// LENS FLARE SYSTEM
// ============================================================================

#ifdef LENS_FLARE

uniform mat4 gbufferProjection;
uniform vec3 sunPosition;
uniform ivec2 eyeBrightness;
uniform int isEyeInWater;
uniform int worldTime;

// Time array for day/night transitions
float ticks = float(worldTime);

float time[7] = float[7](
    ((clamp(ticks, 21000.0, 24000.0) - 21000.0) / 3000.0) + (1.0 - (clamp(ticks, 0.0, 3000.0) / 3000.0)),          // Dusk
    (clamp(ticks, 0.0, 3000.0) / 3000.0) - ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0),                    // Morning
    ((clamp(ticks, 3000.0, 6000.0) - 3000.0) / 3000.0) - ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0),      // Noon
    ((clamp(ticks, 6000.0, 9000.0) - 6000.0) / 3000.0) - ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0),     // Afternoon
    ((clamp(ticks, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(ticks, 12000.0, 15000.0) - 12000.0) / 3000.0),  // Sunset
    ((clamp(ticks, 12000.0, 15000.0) - 12000.0) / 3000.0) - ((clamp(ticks, 21000.0, 24000.0) - 21000.0) / 3000.0),// Night
    ((clamp(ticks, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(ticks, 23250.0, 24000.0) - 23250.0) / 750.0)   // Transition
);

float drawCircle(float radius, float edge, float lensDist, in vec2 texCoord, in float aspectRatio) {
    vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
                 tpos = vec4(tpos.xyz / tpos.w, 1.0);
    vec2 pos = tpos.xy / tpos.z * lensDist;
    vec2 lightPos = pos * 0.5 + 0.5;

    vec2 coord = (texCoord - lightPos) / radius;

    float circle = 1.0 - clamp(pow(coord.x * aspectRatio, 2.0) + pow(coord.y, 2.0), 0.0, 1.0);

    return smoothstep(0.0, 1.0 - edge, circle);
}

mat2 rotate2d(float angle){
  return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

float drawHorizontal(float size, float angle, float edge, float lensDist, in vec2 texCoord) {
    vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
                 tpos = vec4(tpos.xyz / tpos.w, 1.0);
    vec2 pos = tpos.xy / tpos.z * lensDist;
    vec2 lightPos = pos * 0.5 + 0.5;

    vec2 coord = (texCoord - lightPos) * rotate2d(angle);

    return 1.0 - clamp(abs(0.0 - coord.y * 2.0 / size), 0.0, 1.0);
}

vec3 lensFlare(vec3 color, in vec2 texCoord, in float aspectRatio, in sampler2D depthtex0) {
    float lensPower = 0.2;

    vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
                 tpos = vec4(tpos.xyz / tpos.w, 1.0);
    vec2 pos = tpos.xy / tpos.z;
    vec2 lightPos = pos * 0.5 + 0.5;

    float distof = min(clamp(1.2 - lightPos.x, 0.0, lightPos.x), clamp(1.2 - lightPos.y, 0.0, lightPos.y));
    
    // FIX: Use depth buffer to check if the sun is visible against the sky
    float sunVisibility = float(texture2D(depthtex0, lightPos).r >= 1.0) * distof;

    lensPower *= (1.0 - time[5]) * (1.0 - time[6]) * (1.0 - rainStrength) * float(sunPosition.z < 0.0);
    if (isEyeInWater == 1) lensPower *= eyeBrightness.y / 240.0;

    vec3 flare12  = drawHorizontal(0.023, 0.6, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.015, -0.3, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.021, -0.6, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.022, 1.0, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.012, 1.3, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.016, -1.3, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 += drawHorizontal(0.015, -1.5, 0.0, 1.0, texCoord) * vec3(1.0, 0.7, 0.4);
                 flare12 *= drawCircle(0.3, -0.5, 1.0, texCoord, aspectRatio) * 0.25;

    float flare13 = drawCircle(0.1, 0.0, 1.0, texCoord, aspectRatio);

    vec3 flare1 = max(drawCircle(0.3, 0.8, -0.5, texCoord, aspectRatio) - drawCircle(0.3, 0.8, -0.45, texCoord, aspectRatio), 0.0) * vec3(1.0, 0.5, 0.0);
    vec3 flare2 = max(drawCircle(0.3, 0.8, -0.55, texCoord, aspectRatio) - drawCircle(0.3, 0.8, -0.5, texCoord, aspectRatio), 0.0) * vec3(0.5, 1.0, 0.5);
    vec3 flare3 = max(drawCircle(0.3, 0.8, -0.6, texCoord, aspectRatio) - drawCircle(0.3, 0.8, -0.55, texCoord, aspectRatio), 0.0) * vec3(0.2, 0.5, 1.0);

    vec3 flare10 = drawCircle(0.02, 0.3, 0.2, texCoord, aspectRatio) * drawCircle(0.02, 0.3, 0.22, texCoord, aspectRatio) * vec3(1.0, 1.0, 0.0) * 0.5;
    vec3 flare9 = drawCircle(0.04, 0.5, 0.1, texCoord, aspectRatio) * drawCircle(0.04, 0.5, 0.15, texCoord, aspectRatio) * vec3(0.3, 1.0, 0.0) * 0.5;

    vec3 flare8 = drawCircle(0.01, 0.0, -0.1, texCoord, aspectRatio) * drawCircle(0.01, 0.0, -0.11, texCoord, aspectRatio) * vec3(0.0, 1.0, 0.0);

    vec3 flare4 = drawCircle(0.007, 0.0, -0.2, texCoord, aspectRatio) * drawCircle(0.007, 0.0, -0.21, texCoord, aspectRatio) * vec3(1.0, 0.5, 0.0);

    vec3 flare11 = drawCircle(0.07, 0.7, -0.15, texCoord, aspectRatio) * drawCircle(0.07, 0.7, -0.25, texCoord, aspectRatio) * vec3(0.0, 0.6, 1.0) * 0.5;

    vec3 flare5 = max(drawCircle(0.1, 0.7, -0.3, texCoord, aspectRatio) - drawCircle(0.13, 0.3, -0.25, texCoord, aspectRatio), 0.0) * vec3(1.0, 0.5, 0.0);
    vec3 flare6 = drawCircle(0.01, 0.2, -0.4, texCoord, aspectRatio) * drawCircle(0.01, 0.2, -0.41, texCoord, aspectRatio) * vec3(0.0, 1.0, 1.0);
    vec3 flare7 = max(drawCircle(0.07, 0.7, -0.5, texCoord, aspectRatio) - drawCircle(0.1, 0.2, -0.45, texCoord, aspectRatio), 0.0) * vec3(0.2, 0.5, 1.0);

    return color + ((flare1 + flare2 + flare3 + flare4 + flare5 + flare6 + flare7 + flare8 + flare9 + flare10 + flare11) * sunVisibility + (flare12 * (1.0 - flare13)) * sunVisibility) * lensPower;
}

#endif