/*
================================ /// Super Duper Vanilla v1.3.8 /// ================================
    Water Coloring — Eclipse absorption port.
================================ /// Super Duper Vanilla v1.3.8 /// ================================
*/

vec3 eclipseWaterAbsorption(float depth) {
    vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B)
                    + Dirt_Amount * vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
    return exp(-totEpsilon * max(depth, 0.0));
}

vec3 _sildurWaterColor(float depth, float dayAmt) {
    vec3 eps = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B)
             + Dirt_Amount * vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);

    float ref = clamp(depth * 0.5 + 6.0, 6.0, 12.0);
    vec3 colour = exp(-eps * ref);

    vec3 dayCol   = colour * 2.2;
    vec3 nightCol = colour * vec3(0.0, 0.15, 0.30);

    return clamp(mix(nightCol, dayCol, clamp(dayAmt, 0.0, 1.0)), 0.0, 1.0);
}

vec3 getWaterColor(float blockDepth, float dayCycleAdjust, float dayCycle,
                   float waveInfluence, float normZ, float rainStrength,
                   int isEyeInWater, vec3 sunCol, vec3 moonCol) {
    return _sildurWaterColor(blockDepth, dayCycleAdjust);
}

float getWaterNormalDepthInfluence(float waterNormalZ, float blockDepth) {
    return mix(blockDepth, blockDepth * 1.5, clamp(1.0 - waterNormalZ, 0.0, 1.0) * 0.3);
}

vec3 blendWaterRefraction(vec3 waterColor, vec3 refractedColor, float depth, float smoothness) {
    return mix(waterColor, refractedColor, mix(0.65, 0.12, clamp(depth * 0.12, 0.0, 1.0)) * smoothness);
}

vec3 getWaterFogColor(vec3 baseWaterColor, float depth, float dayCycleAdjust) {
    float fd = clamp(depth * 0.15, 0.0, 1.0);
    return mix(baseWaterColor, mix(baseWaterColor * 0.20, baseWaterColor * 0.52, dayCycleAdjust), fd);
}
