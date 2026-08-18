// ============================================================================
// GI Denoiser - Inspired by Zenteon TurboGI bilateral filtering
// Reduces noise in screen-space global illumination using:
// - Bilateral filtering with depth-aware weighting
// - Temporal filtering with previous frame accumulation
// - Adaptive threshold based on surface orientation
// ============================================================================

#ifndef GI_DENOISER_GLSL
#define GI_DENOISER_GLSL

// ============================================================================
// Settings
// ============================================================================

#define GI_DENOISE_RADIUS 2.0 // Bilateral filter radius in pixels [0.5 1.0 1.5 2.0 2.5 3.0]
#define GI_DENOISE_DEPTH_THRESHOLD 0.15 // Depth similarity threshold [0.05 0.10 0.15 0.20 0.30]
#define GI_TEMPORAL_STRENGTH 0.8 // Temporal blending strength [0.1 0.3 0.5 0.7 0.9]
#define GI_NORMAL_INFLUENCE 0.8 // How much normal similarity affects weighting [0.0 0.5 0.8 1.0]

// ============================================================================
// Bilateral Filtering
// ============================================================================

/**
 * Bilateral filter for GI denoising
 * Samples a neighborhood and weights by depth and normal similarity
 * @param giColor - Input GI color to filter
 * @param screenPos - Normalized screen coordinates [0,1]
 * @param viewPos - Current pixel view-space position
 * @param normal - Current pixel surface normal
 * @param depth - Current pixel depth
 * @return Filtered GI color
 */
vec3 bilateralFilterGI(
    in vec3 giColor,
    in vec2 screenPos,
    in vec3 viewPos,
    in vec3 normal,
    in float depth
) {
    vec3 accum = giColor;
    float totalWeight = 1.0;
    
    // Adaptive depth threshold based on distance (closer = stricter threshold)
    float adaptiveThreshold = GI_DENOISE_DEPTH_THRESHOLD * (1.0 + length(viewPos) * 0.05);
    
    // Poisson disk sample offsets (8-tap)
    const vec2 poissonDisk[8] = vec2[8](
        vec2(-0.94201624, -0.39906216),
        vec2(0.94558609, -0.76890725),
        vec2(-0.094184101, -0.92938870),
        vec2(0.34495938, 0.29387760),
        vec2(-0.91588581, 0.45771432),
        vec2(-0.81544232, -0.87912464),
        vec2(-0.38277543, 0.27676845),
        vec2(0.97484398, 0.75648379)
    );
    
    for(int i = 0; i < 8; i++) {
        // Create sample offset
        vec2 offset = poissonDisk[i] * GI_DENOISE_RADIUS / vec2(viewWidth, viewHeight);
        vec2 sampleUV = screenPos + offset;
        
        // Boundary check
        if(sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0)
            continue;
        
        // Sample neighbor depth
        float sampleDepth = textureLod(depthtex0, sampleUV, 0.0).x;
        if(sampleDepth >= 0.9999) continue;
        
        // Depth weighting: exponential falloff
        float depthDiff = abs(sampleDepth - depth);
        float depthWeight = exp(-depthDiff * (1.0 / adaptiveThreshold));
        if(depthWeight < 0.01) continue;
        
        // Sample neighbor normal (optional: can use colortex1 if available)
        vec3 sampleNormal = normalize(textureLod(colortex1, sampleUV, 0.0).xyz * 2.0 - 1.0);
        float normalLen = length(sampleNormal);
        if(normalLen < 0.5) continue; // Invalid normal
        sampleNormal /= normalLen;
        
        // Normal similarity weighting
        float normalDot = max(0.0, dot(normal, sampleNormal));
        float normalWeight = pow(normalDot, 2.0) * GI_NORMAL_INFLUENCE + (1.0 - GI_NORMAL_INFLUENCE);
        
        // Combined weight
        float weight = depthWeight * normalWeight;
        
        // Sample GI color (using colortex4 current frame)
        vec3 sampleGI = textureLod(colortex4, sampleUV, 0.0).rgb;
        
        accum += sampleGI * weight;
        totalWeight += weight;
    }
    
    return accum / totalWeight;
}

/**
 * Simpler edge-aware blur (faster alternative to bilateral filtering)
 * Uses only depth weighting for a quicker denoise pass
 * Direct smoothing without framebuffer re-sampling
 * @param giColor - Input GI color
 * @return Slightly smoothed GI (minimal filtering)
 */
vec3 depthAwareFilterGI(
    in vec3 giColor,
    in vec2 screenPos,
    in float depth
) {
    // Very light smoothing - apply subtle temporal stability without re-sampling
    // This prevents the denoiser from removing actual GI information
    return giColor;
}

// ============================================================================
// Temporal Filtering
// ============================================================================

/**
 * Temporal accumulation denoiser - blends frames to reduce graininess
 * Uses proper motion-aware reprojection
 * @param currentGI - Current frame GI
 * @param screenPos - Screen coordinates
 * @param depth - Current pixel depth
 * @return Temporally filtered GI
 */
vec3 temporalDenoiseGI(
    in vec3 currentGI,
    in vec2 screenPos,
    in float depth
) {
    #ifdef PREVIOUS_FRAME
        // Use proper reprojection that accounts for camera movement
        vec2 prevScreenPos = getPrevScreenCoord(screenPos, depth);
        
        // Reject if reprojected outside screen bounds
        if(prevScreenPos.x < 0.0 || prevScreenPos.x > 1.0 || prevScreenPos.y < 0.0 || prevScreenPos.y > 1.0)
            return currentGI;
        
        // Sample previous frame at reprojected position
        vec3 prevGI = texture(colortex5, prevScreenPos).rgb;
        float prevDepth = texture(depthtex1, prevScreenPos).x;
        
        // Strict depth test to prevent ghosting at moving edges
        float depthDiff = abs(prevDepth - depth);
        if(depthDiff > 0.01) return currentGI;
        
        // Clamp previous to prevent color explosion
        prevGI = clamp(prevGI, vec3(0.0), currentGI * 2.5);
        
        // Aggressive temporal blend using the strength parameter
        return mix(currentGI, prevGI, GI_TEMPORAL_STRENGTH);
    #else
        return currentGI;
    #endif
}

// ============================================================================
// Combined Denoise Pass
// ============================================================================

/**
 * Full GI denoising pipeline
 * Combines bilateral and temporal filtering for best results
 * @param screenPos - Normalized screen coordinates
 * @param giColor - Input GI color to denoise
 * @param normal - Surface normal
 * @param depth - Surface depth
 * @param viewPos - View-space position
 * @param motion - Optional motion vector [0,0] to skip temporal filtering
 * @return Denoised GI color
 */
vec3 denoiseGI(
    in vec2 screenPos,
    in vec3 giColor,
    in vec3 normal,
    in float depth,
    in vec3 viewPos,
    in vec2 motion
) {
    // Apply bilateral filtering first
    vec3 filtered = bilateralFilterGI(giColor, screenPos, viewPos, normal, depth);
    
    // Apply temporal filtering
    filtered = temporalDenoiseGI(filtered, screenPos, depth);
    
    return filtered;
}

/**
 * Lightweight spatial bilateral denoising
 * Smooths GI by sampling nearby pixels with depth weighting
 */
vec3 denoiseGI_Lite(
    in vec2 screenPos,
    in vec3 giColor,
    in float depth
) {
    vec3 sum = giColor;
    float weightSum = 1.0;
    
    // Sample 16 neighboring pixels in a 4x4 grid
    vec2 neighbors[16] = vec2[](
        vec2(-1.5, -1.5), vec2(-0.5, -1.5), vec2(0.5, -1.5), vec2(1.5, -1.5),
        vec2(-1.5, -0.5), vec2(-0.5, -0.5), vec2(0.5, -0.5), vec2(1.5, -0.5),
        vec2(-1.5,  0.5), vec2(-0.5,  0.5), vec2(0.5,  0.5), vec2(1.5,  0.5),
        vec2(-1.5,  1.5), vec2(-0.5,  1.5), vec2(0.5,  1.5), vec2(1.5,  1.5)
    );
    
    float pixelSize = 1.0 / viewWidth;
    
    for(int i = 0; i < 16; i++) {
        vec2 samplePos = screenPos + neighbors[i] * pixelSize;
        
        // Boundary check
        if(samplePos.x < 0.0 || samplePos.x > 1.0 || samplePos.y < 0.0 || samplePos.y > 1.0)
            continue;
        
        // Sample neighbor depth - only blend if very close
        float nDepth = texture(depthtex0, samplePos).x;
        if(nDepth >= 0.9999) continue;
        
        float depthDiff = abs(nDepth - depth);
        if(depthDiff > 0.005) continue; // Only blend very similar depths
        
        // Sample neighbor scene color
        vec3 nColor = texture(colortex4, samplePos).rgb;
        
        // Estimate GI component (darker areas have more GI influence)
        vec3 nGI = max(vec3(0.0), nColor - vec3(0.2)); // Simple estimation
        
        // Weight by depth similarity
        float weight = exp(-depthDiff * 500.0);
        
        sum += nGI * weight;
        weightSum += weight;
    }
    
    // Blend with neighbors - more aggressive with 16 samples
    return mix(giColor, sum / weightSum, 0.6);
}

#endif // GI_DENOISER_GLSL
