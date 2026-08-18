vec2 getWeatherWave(in vec3 vertexEyePlayerPos, in vec2 vertexWorldPosXZ){
    // Get wave coord
    // Use the same base wind frequency as terrain (no frequency doubling during rain)
    const float BASE_WIND = 4.0;
    float windStrength = sin(-sumOf(vertexWorldPosXZ) * WIND_FREQUENCY * 0.5 + vertexFrameTime * BASE_WIND);
    // Apply wave animation
    return vertexEyePlayerPos.xz + vertexEyePlayerPos.y * windStrength * 0.25;
}