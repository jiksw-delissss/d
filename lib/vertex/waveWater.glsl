#ifndef WAVE_HEIGHT
#define WAVE_HEIGHT 0.10
#endif

float GetWavesVertex(vec3 position, float animateTime) {
    float speed = 0.9;
    vec2 p = position.xz / 20.0;
    p.xy -= position.y / 20.0;
    p.x = -p.x;

    p.x += (animateTime / 40.0) * speed;
    p.y -= (animateTime / 40.0) * speed;

    float weights = 0.0;
    float allwaves = 0.0;

    float wave;
    // layer 0 - primary diagonal waves
    wave = sin(p.x * 2.0 + p.y * 1.2) * 0.5 + 0.5;
    allwaves += wave; weights += 1.0;

    // layer 0b - secondary direction (perpendicular)
    wave = sin(p.y * 1.8 - p.x * 0.8) * 0.5 + 0.5;
    allwaves += wave * 4.0; weights += 4.0;

    // layer 1
    p /= 2.1; p.y -= (animateTime / 20.0) * speed; p.x -= (animateTime / 30.0) * speed;
    wave = sin(p.x * 2.0 + p.y * 1.4) * 0.5 + 0.5;
    allwaves += wave * 4.1; weights += 4.1;

    // layer 1b - cross direction
    wave = sin(p.y * 1.6 - p.x * 1.2) * 0.5 + 0.5;
    allwaves += wave * 7.0; weights += 7.0;

    // layer 2
    p /= 1.5; p.x += (animateTime / 20.0) * speed;
    wave = sin(p.x * 1.0 + p.y * 0.75) * 0.5 + 0.5;
    allwaves += wave * 17.25; weights += 17.25;

    // layer 2b - perpendicular detail
    wave = sin(p.y * 1.2 - p.x * 0.6) * 0.5 + 0.5;
    allwaves += wave * 18.0; weights += 18.0;

    // layer 3
    p /= 1.5; p.x -= (animateTime / 55.0) * speed;
    wave = sin(p.x * 1.0 + p.y * 0.75) * 0.5 + 0.5;
    allwaves += wave * 15.25; weights += 15.25;

    // layer 3b - cross direction detail
    wave = sin(p.y * 0.9 - p.x * 0.5) * 0.5 + 0.5;
    allwaves += wave * 16.0; weights += 16.0;

    // layer 4 (detail, abs based - sharp crests at zero crossings)
    p /= 1.9; p.x += (animateTime / 155.0) * speed;
    wave = abs(sin(p.x * 1.0 + p.y * 0.8));
    wave *= 29.25;
    allwaves += wave; weights += 29.25;

    // layer 4b - cross direction detail
    wave = abs(sin(p.y * 1.1 - p.x * 0.7));
    wave *= 30.0; allwaves += wave; weights += 30.0;

    // layer 5 (mirrored detail)
    p /= 2.0; p.x += (animateTime / 155.0) * speed;
    wave = abs(sin(p.x * 1.0 + p.y * 0.8));
    wave *= 15.25; allwaves += wave; weights += 15.25;

    // layer 5b - perpendicular mirrored detail
    wave = abs(sin(p.y * 1.0 - p.x * 0.6));
    wave *= 18.0; allwaves += wave; weights += 18.0;

    allwaves /= weights;
    return allwaves;
}

// Wave animation movements
vec3 getWaterWave(in vec3 vertexEyePlayerPos, in vec2 vertexWorldPosXZ, in float id, in float currTime){
    if(id >= 11100 && id <= 11199){
        float scaledTime = currTime * WATER_VERTEX_WAVE_SPEED;

        // Current displacement
        if(CURRENT_SPEED > 0){
            float currentStrength = cos(-sumOf(vertexWorldPosXZ) * CURRENT_FREQUENCY + scaledTime * CURRENT_SPEED);
            vertexEyePlayerPos.y += currentStrength * 0.05;
        }

        // Vertex wave displacement
        vec3 pos = vec3(vertexWorldPosXZ.x, 0.0, vertexWorldPosXZ.y);
        float waveHeight = GetWavesVertex(pos, scaledTime);
        vertexEyePlayerPos.y += clamp(waveHeight * WAVE_HEIGHT, -WAVE_HEIGHT, WAVE_HEIGHT);
    }

    return vertexEyePlayerPos;
}
