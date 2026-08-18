// Cartoon-style edge detection outlines - depth only version for final.glsl
// Uses only depth buffer (colortex1 is not available in final pass)

// Edge detection based on depth discontinuities only
// Edge detection function now accepts a depth texture to allow per-frame evaluation
#ifdef DISTANT_HORIZONS
float getOutlineDepthAtUV(in vec2 coord) {
    float mainDepth = textureLod(depthtex0, coord, 0).x;
    return mainDepth == 1.0 ? textureLod(dhDepthTex0, coord, 0).x : mainDepth;
}
#else
float getOutlineDepthAtUV(in vec2 coord) {
    return textureLod(depthtex0, coord, 0).x;
}
#endif

float cartoon_detectOutlineDepth(sampler2D depthTex, vec2 uv, float centerDepth, float nearVal, float farVal) {
    if (centerDepth >= 1.0) return 0.0;

    vec2 ts = 1.0 / vec2(viewWidth, viewHeight);
    float th = float(CARTOON_OUTLINE_THICKNESS);

    vec2 offsets[4];
    offsets[0] = vec2( th, 0.0) * ts;
    offsets[1] = vec2(-th, 0.0) * ts;
    offsets[2] = vec2(0.0,  th) * ts;
    offsets[3] = vec2(0.0, -th) * ts;

    // Linear depth calculation
    float centerL = (2.0 * nearVal * farVal) / (farVal + nearVal - centerDepth * (farVal - nearVal));

    // Check depth discontinuities
    float maxEdge = 0.0;
    for (int i = 0; i < 4; i++) {
        float nd = getOutlineDepthAtUV(uv + offsets[i]);
        if (nd >= 1.0) {
            // Sky edge - strong outline
            return 0.8;
        }

        float neighborL = (2.0 * nearVal * farVal) / (farVal + nearVal - nd * (farVal - nearVal));
        float depthDiff = abs(centerL - neighborL) / max(centerL, 0.1);

        // Increased threshold to reduce false chunk boundary detection
        if (depthDiff > 0.15) {
            maxEdge = max(maxEdge, min(0.7, depthDiff * 2.0));
        }
    }

    return maxEdge;
}

// Apply outline to color - depth only version
vec3 applyCartoonOutline(vec3 color, sampler2D depthTex, vec2 texCoord, float depth, float nearVal, float farVal) {
    #ifdef CARTOON_OUTLINE_ENABLE
        float edge = cartoon_detectOutlineDepth(depthTex, texCoord, depth, nearVal, farVal);
        if (edge > 0.0) {
            // Use a black ink outline for cartoon style (strong silhouette)
            vec3 outlineColor = vec3(0.0, 0.0, 0.0);
            color = mix(color, outlineColor, edge * 0.95);
        }
    #endif
    return color;
}