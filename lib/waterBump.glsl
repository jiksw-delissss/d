const vec2 wave_size[3] = vec2[](
	vec2(48.,12.),
	vec2(12.,48.),
	vec2(32.,32.)
);

const float radiance = 2.39996;

float _causticWave(in vec3 position, in float animateTime) {
    float waveSpeed = 0.09;
    vec3 pos = position;
    
    // Similar to water wave function
    pos.x += sin(pos.z * 2.0 + animateTime * waveSpeed * 25.0) * 0.1;
    pos.z += cos(pos.x * 1.5 + animateTime * waveSpeed * 25.0) * 0.1;
    
    vec2 coord = vec2(pos.xz / 200.0);
    
    float noise = texture(noisetex, coord * 1.5 + vec2(animateTime / 20.0 * waveSpeed)).x / 1.5;
    noise += texture(noisetex, coord * 1.5 - vec2(animateTime / 15.0 * waveSpeed)).x / 1.5;
    noise += texture(noisetex, coord * 3.5 + vec2(animateTime / 12.0 * waveSpeed)).x / 3.5;
    noise += texture(noisetex, coord * 3.5 - vec2(animateTime / 9.0 * waveSpeed)).x / 3.5;
    noise += texture(noisetex, coord * 7.0 + vec2(animateTime / 6.0 * waveSpeed)).x / 7.0;
    noise += texture(noisetex, coord * 7.0 - vec2(animateTime / 4.0 * waveSpeed)).x / 7.0;
    
    return (noise / 6.0) * 3.5;
}

float waterCaustics(vec3 worldPos, vec3 sunVec, float surfacePos) {
    // Clamp sunVec.y so caustic doesn't accelerate at sunset (1/y → ∞ near horizon)
    float sunY = max(abs(sunVec.y), 0.15);
    vec3 projectedPos = worldPos + (sunVec / sunY) * surfacePos;

    // Scale to match H2NWater: uv = worldPos.xz * waterTileSizeInv, pos = uv * 20
    const float scale = 20.0 * waterTileSizeInv;
    vec3 causticPos = vec3(projectedPos.x * scale, 0.0, projectedPos.z * scale);

    float animateTime = frameTimeCounter * CURRENT_SPEED * 0.0625;

    // Much finer delta for sharp, thin caustics
    float delta = 0.08;
    float h0 = _causticWave(causticPos,                          animateTime);
    float h1 = _causticWave(causticPos + vec3(delta, 0.0, 0.0), animateTime);
    float h2 = _causticWave(causticPos + vec3(0.0,   0.0, delta), animateTime);

    float curvature = h0 - 0.5 * (h1 + h2);
    // Very high exponent creates thin stripe-like caustics
    float caustic = exp(curvature * 5.0);
    
    // Subtle bloom: just a light amplification
    caustic = caustic * 1.3;
    
    return caustic;
}
float getWaterHeightmap(vec2 posxz, in float largeWaves, in float largeWavesCurved) {
	vec2 pos = posxz;

	float movement = frameTimeCounter * 0.035 * WATER_WAVE_SPEED;

	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	float heightSum = 0.0;
	for (int i = 0; i < 3; i++){

		pos = rotationMatrix * pos;
		heightSum += texture(noisetex, pos / wave_size[i] + largeWavesCurved * 0.5 + movement).b;
	}

	return (heightSum/4.5) * max(largeWavesCurved,0.3);
}

vec3 getWaveNormal(vec3 waterPos, vec3 playerpos){
	
	float largeWaves = texture(noisetex, waterPos.xy / 600.0 ).b;
	float largeWavesCurved = pow(1.0-pow(1.0-largeWaves,2.5),4.5);
	largeWavesCurved = mix(1.0-largeWavesCurved, largeWavesCurved, PATCHY_WAVE_BLEND);
	
	#ifdef HYPER_DETAILED_WAVES
		float deltaPos = 0.025;
	#else
		float deltaPos = mix(WAVES_A_RADIUS, WAVES_B_RADIUS, largeWavesCurved);
		// reduce high frequency detail as distance increases. reduces noise on waves. why have more details than pixels?
		float range = min(length(playerpos) / (16.0*24.0), 3.0);
		deltaPos += range;
	#endif

	vec2 coord = waterPos.xy;

	float h0 = getWaterHeightmap(coord, largeWaves, largeWavesCurved);
	float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0), largeWaves,largeWavesCurved);
	float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos), largeWaves,largeWavesCurved);

	float xDelta = (h1-h0)/deltaPos;
	float yDelta = (h3-h0)/deltaPos;

	vec3 wave = normalize(vec3(xDelta, yDelta, 1.0-pow(abs(xDelta+yDelta),2.0)));

	return wave;
}
