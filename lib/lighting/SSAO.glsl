// Cheap SSAO -- screen-space depth horizon comparison.
// 4 taps, no per-tap matrix reconstruction. Output matches original 0..0.25 range.
float getSSAO(in vec3 screenPos, in vec3 viewNormal){
    #if ANTI_ALIASING >= 2
        vec2 rng = fract(getRng3(ivec2(gl_FragCoord.xy) & 255).xy + frameFract);
    #else
        vec2 rng = getRng3(ivec2(gl_FragCoord.xy) & 255).xy;
    #endif

    // Rotate taps by noise angle to avoid banding
    float angle = rng.x * 6.28318530718;
    float ca = cos(angle), sa = sin(angle);

    // Linearize center depth for radius scaling
    float linearDepth = near / (1.0 - screenPos.z);
    float uvRadius = clamp(1.2 / linearDepth, 0.004, 0.02);

    vec2 dirs[4];
    dirs[0] = vec2( ca,  sa) * uvRadius;
    dirs[1] = vec2(-ca, -sa) * uvRadius;
    dirs[2] = vec2(-sa,  ca) * uvRadius * 0.7;
    dirs[3] = vec2( sa, -ca) * uvRadius * 0.7;

    float occlusion = 0.0;
    for(int i = 0; i < 4; i++){
        float tapDepth = textureLod(depthtex0, screenPos.xy + dirs[i], 0).x;

        // Linearize both depths for a physically meaningful comparison
        float centerLinear = near / (1.0 - screenPos.z);
        float tapLinear    = near / (1.0 - clamp(tapDepth, 0.0001, 0.9999));

        // Tap is in front of center = occluding
        float diff = centerLinear - tapLinear;

        // Range check: only count occlusion within a reasonable world-space radius
        // Below threshold = same surface (no occlusion), above = too far = halo suppression
        float weight = clamp(diff / 0.5, 0.0, 1.0) * (1.0 - clamp(diff / 3.0, 0.0, 1.0));
        occlusion += weight;
    }

    // Output: 0.25 = fully open, 0.0 = fully occluded (4 taps * 0.0625 each)
    return 0.25 - occlusion * 0.0625;
}
