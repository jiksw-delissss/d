#ifndef MOTION_BLUR_SAMPLES
#define MOTION_BLUR_SAMPLES 128 // Number of samples per side (Total samples = (SAMPLES * 2) + 1)
#endif

vec3 motionBlur(in vec3 currColor, in float depth, in float dither){
    // Calculate base per-pixel screen-space velocity (used for looking around)
    vec2 prevPos = vec2(viewWidth, viewHeight) * getPrevScreenCoord(texCoord, depth);
    vec2 velocity = (gl_FragCoord.xy - prevPos) * MOTION_BLUR_STRENGTH;

    // RACING GAME BOOST: Add a radial zoom blur based on camera translation
    // This makes moving forward/backward heavily blur the edges of the screen
    float camDeltaLength = length(camPosDelta);
    if (camDeltaLength > 0.01) {
        // Vector from center of screen, corrected for aspect ratio
        vec2 radialDir = (texCoord - 0.5) * vec2(viewWidth / viewHeight, 1.0);
        // Amplify the radial blur based on how fast the player is moving
        velocity += radialDir * camDeltaLength * MOTION_BLUR_STRENGTH * 20.0;
    }

    // Early out for static pixels to save performance
    float velLength = dot(velocity, velocity);
    if(velLength < 1.0) return currColor;

    vec3 colorAccum = currColor;
    float totalWeight = 1.0;

    // Centered sampling along the velocity vector with dithering
    for(int i = 1; i <= MOTION_BLUR_SAMPLES; ++i){
        // Calculate normalized offset, adding dither to break up banding
        float t = (float(i) + dither) / float(MOTION_BLUR_SAMPLES + 1);
        vec2 offset = velocity * t;

        // Sample in the positive direction
        ivec2 pos1 = ivec2(gl_FragCoord.xy + offset);
        pos1 = clamp(pos1, ivec2(0), ivec2(viewWidth - 1, viewHeight - 1));
        colorAccum += texelFetch(colortex4, pos1, 0).rgb;

        // Sample in the negative direction
        ivec2 pos2 = ivec2(gl_FragCoord.xy - offset);
        pos2 = clamp(pos2, ivec2(0), ivec2(viewWidth - 1, viewHeight - 1));
        colorAccum += texelFetch(colortex4, pos2, 0).rgb;

        totalWeight += 2.0;
    }

    return colorAccum / totalWeight;
}