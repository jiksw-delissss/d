#ifdef DISTANT_HORIZONS
float getOutlineDepth(in ivec2 coord) {
    float mainDepth = texelFetch(depthtex0, coord, 0).x;
    return mainDepth == 1.0 ? texelFetch(dhDepthTex0, coord, 0).x : mainDepth;
}
#else
float getOutlineDepth(in ivec2 coord) {
    return texelFetch(depthtex0, coord, 0).x;
}
#endif

float getOutline(in sampler2D depthTex, in ivec2 iUv, in float depthOrigin){
    ivec2 topRightCorner = iUv - OUTLINE_PIXEL_SIZE;
    ivec2 bottomLeftCorner = iUv + OUTLINE_PIXEL_SIZE;

    // (1.0 - screenPos.z) / near
    // near / (1.0 - screenPos.z)

    #if OUTLINES == 1
        float depth0 = near / (1.0 - getOutlineDepth(topRightCorner));
        float depth1 = near / (1.0 - getOutlineDepth(bottomLeftCorner));
        float depth2 = near / (1.0 - getOutlineDepth(ivec2(topRightCorner.x, bottomLeftCorner.y)));
        float depth3 = near / (1.0 - getOutlineDepth(ivec2(bottomLeftCorner.x, topRightCorner.y)));

        float sumDepth = depth0 + depth1 + depth2 + depth3;

        // Calculate standard outlines
        return saturate(sumDepth - (near * 4.0) / (1.0 - depthOrigin));
    #else
        float depth0 = 64.0 / (1.0 - getOutlineDepth(topRightCorner));
        float depth1 = 64.0 / (1.0 - getOutlineDepth(bottomLeftCorner));
        float depth2 = 64.0 / (1.0 - getOutlineDepth(ivec2(topRightCorner.x, bottomLeftCorner.y)));
        float depth3 = 64.0 / (1.0 - getOutlineDepth(ivec2(bottomLeftCorner.x, topRightCorner.y)));

        float sumDepth = depth0 + depth1 + depth2 + depth3;

        // Calculate dungeons outlines
        return saturate((1.0 - depthOrigin) * sumDepth - 256.0);
    #endif
}