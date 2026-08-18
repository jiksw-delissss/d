// Wave animation movements for shadow
// Ensure `rainStrength` is declared for any shader that includes this file
uniform float rainStrength;
// Optional uniforms provided by the engine to drive a time-based rain transition
#ifdef RAIN_TRANSITION_UNIFORM
    uniform float lastRainToggleTime; // time of last rain state toggle
    uniform int lastRainToggleState;  // 1 if toggled TO raining, 0 if toggled TO not raining
    uniform float rainTransitionSeconds; // transition duration in seconds
#endif

vec3 getTerrainWave(in vec3 vertexEyePlayerPos, in vec2 vertexWorldPosXZ, in float midBlockY, in float id, in float outside, in float currTime){
    // Determine effective wind speed: 4.0 when not raining, doubled when raining.
    // Compute a smooth rain mix fallback from `rainStrength` so fades work
    // even when the engine does not provide transition uniforms.
    float baseWind = 4.0;
    float effectiveWind = baseWind;

    const float RAIN_MIN_DEF_V = 0.12;
    const float RAIN_FADE_V = 0.9;
    float rainMix = smoothstep(RAIN_MIN_DEF_V, RAIN_MIN_DEF_V + RAIN_FADE_V, rainStrength);

    // compute a unified mix factor to drive transitions (used for phase interpolation)
    float mixFactor = rainMix;

#ifdef RAIN_TRANSITION_UNIFORM
    float transMix = 0.0;
    if(rainTransitionSeconds > 0.0){
        float dt = currTime - lastRainToggleTime;
        float u = clamp(dt / rainTransitionSeconds, 0.0, 1.0);
        transMix = (lastRainToggleState == 1) ? smoothstep(0.0, 1.0, u) : (1.0 - smoothstep(0.0, 1.0, u));
        mixFactor = max(rainMix, transMix);
    }
#endif

    // derive an effective wind value for checks (kept simple)
    effectiveWind = mix(baseWind, baseWind * 2.0, mixFactor);

    // Wind affected blocks
    if(effectiveWind > 0.0){
        // Use a constant base frequency for phase progression and interpolate
        // amplitude to avoid perceived speed spikes during transitions.
        float phase = currTime * baseWind;
        float amplitude = mix(1.0, 2.0, mixFactor);

        // Create more natural waves using multiple frequencies layered together
        vec2 pos = id == 10801 ? floor(vertexWorldPosXZ) : vertexWorldPosXZ;
        
        // Primary wave - slow, large wavelength
        float wave1 = sin(-pos.x * WIND_FREQUENCY * 0.5 + phase * 0.8 - pos.y * 0.02) * 0.6;
        // Secondary wave - medium frequency, adds complexity
        float wave2 = sin(-pos.y * WIND_FREQUENCY * 0.8 + phase * 1.2 + pos.x * 0.01) * 0.3;
        // Tertiary wave - faster, subtle detail
        float wave3 = sin(-(pos.x + pos.y) * WIND_FREQUENCY * 1.3 + phase * 1.5) * 0.1;
        
        // Combine waves with smooth falloff
        float windStrength = (wave1 + wave2 + wave3) * outside * amplitude;
        
        // Height-based modulation for more natural look
        float heightMod = smoothstep(0.0, 2.0, midBlockY) * smoothstep(4.0, 2.5, midBlockY);
        windStrength *= mix(1.0, 0.7, heightMod);

        // Simple blocks, horizontal movement
        if(id >= 10000 && id <= 10099){
            vertexEyePlayerPos.xz -= windStrength * 0.1;
            return vertexEyePlayerPos;
        }

        // Single and double grounded cutouts
        if(id >= 10600 && id <= 10799){
            float isUpper = midBlockY - (id >= 10700 ? 1.5 : 0.5);

            // Interactive short grass: amplify sway when player is close
            float factor = 1.0;
            if(id == 10603){
                float dist = length(vertexEyePlayerPos.xz);
                factor = 1.0 + (1.0 - clamp(dist / 2.0, 0.0, 1.0)) * 3.0; // amplify up to 4x when close
            }

            vertexEyePlayerPos.xz += isUpper * windStrength * factor * 0.1;
            return vertexEyePlayerPos;
        }

        // Single hanging cutouts
        if(id >= 10800 && id <= 10899 && id != 10801){
            float isLower = midBlockY + 0.5;
            vertexEyePlayerPos.xz += isLower * windStrength * 0.05;
            return vertexEyePlayerPos;
        }

        // Multi wall cutouts
        if(id >= 10900 && id <= 10999){
            vertexEyePlayerPos.xz += windStrength * 0.05;
            return vertexEyePlayerPos;
        }
    }

    // Current affected blocks
    if(CURRENT_SPEED > 0){
        // Calculate current strength using multiple frequencies for organic feel
        vec2 pos = vertexWorldPosXZ;
        
        // Layer multiple current waves
        float current1 = cos(-pos.x * CURRENT_FREQUENCY * 0.6 + currTime * CURRENT_SPEED * 0.9) * 0.5;
        float current2 = cos(-pos.y * CURRENT_FREQUENCY * 0.9 + currTime * CURRENT_SPEED * 1.1 + pos.x * 0.015) * 0.3;
        float current3 = cos(-(pos.x + pos.y) * CURRENT_FREQUENCY * 1.2 + currTime * CURRENT_SPEED * 0.7) * 0.2;
        
        float currentStrength = (current1 + current2 + current3);

        // Simple blocks, vertical movement
        if(id >= 11100 && id <= 11199){
            vertexEyePlayerPos.y += currentStrength * 0.05;
            return vertexEyePlayerPos;
        }

        // Single and double grounded cutouts
        if(id >= 11600 && id <= 11799){
            float isUpper = midBlockY - (id >= 11700 ? 1.5 : 0.5);
            vertexEyePlayerPos.xz += isUpper * currentStrength * 0.1;
            return vertexEyePlayerPos;
        }
    }

    return vertexEyePlayerPos;
}