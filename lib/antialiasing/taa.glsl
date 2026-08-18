// Simplified TAA - prefer current frame to reduce ghosting/jitter
vec3 textureTAA(in ivec2 screenTexelCoord){
    // Current color
    vec3 currColor = texelFetch(colortex4, screenTexelCoord, 0).rgb;
    // Previous color (reprojected)
    float currDepth = texelFetch(depthtex0, screenTexelCoord, 0).x;
    vec2 prevUV = getPrevScreenCoord(texCoord, currDepth);
    vec3 prevColor = textureLod(colortex5, prevUV, 0).rgb;

    // Neighborhood samples for history clamping
    vec3 nearCol0 = texelFetch(colortex4, ivec2(screenTexelCoord.x - 1, screenTexelCoord.y), 0).rgb;
    vec3 nearCol1 = texelFetch(colortex4, ivec2(screenTexelCoord.x, screenTexelCoord.y - 1), 0).rgb;
    vec3 nearCol2 = texelFetch(colortex4, ivec2(screenTexelCoord.x + 1, screenTexelCoord.y), 0).rgb;
    vec3 nearCol3 = texelFetch(colortex4, ivec2(screenTexelCoord.x, screenTexelCoord.y + 1), 0).rgb;

    vec3 boxMin = min(currColor, min(nearCol0, min(nearCol1, min(nearCol2, nearCol3))));
    vec3 boxMax = max(currColor, max(nearCol0, max(nearCol1, max(nearCol2, nearCol3))));

    // Clamp previous color to neighborhood to avoid excessive ghosting
    prevColor = clamp(prevColor, boxMin, boxMax);

    // Motion-based weighting: reduce history when reprojection motion is large
    float motion = length(prevUV - texCoord);
    const float MOTION_SCALE = 8.0; // higher => history drops faster with motion
    float motionFactor = clamp(motion * MOTION_SCALE, 0.0, 1.0);

    // Base previous weight when stationary
    float prevWeight = mix(0.9, 0.15, motionFactor);

    // Depth mismatch check - if previous depth differs a lot, discard history
    #ifdef DEPTH_MISMATCH_CHECK
        float prevDepth = textureLod(depthtex1, prevUV, 0).x;
        // Simple absolute depth difference threshold in clip-space
        if (abs(prevDepth - currDepth) > 0.02) {
            prevWeight = 0.0;
        }
    #endif

    float currWeight = 1.0 - prevWeight;
    return currColor * currWeight + prevColor * prevWeight;
}
