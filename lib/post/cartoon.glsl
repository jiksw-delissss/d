// Cartoon/Cel shading post-processing effects
// All function names are prefixed with 'cartoon_' to avoid conflicts with SDV

// Luma calculation
float cartoon_luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Filmic contrast curve
vec3 cartoon_filmicCurve(vec3 c, float str) {
    c = c * 0.97 + 0.03;
    c = c * (1.0 + c * str * 0.1) / (1.0 + c * str * 0.22);
    return c;
}

// Saturation adjustment with highlight protection
vec3 cartoon_adjustSat(vec3 c, float sat) {
    float l = cartoon_luma(c);
    float protect = 1.0 - smoothstep(0.6, 1.0, l) * 0.4;
    return mix(vec3(l), c, sat * protect);
}

// Color grading - warm shadows, cool highlights
vec3 cartoon_colorGrade(vec3 c) {
    float l = cartoon_luma(c);
    vec3 warmShadow    = vec3(1.06, 0.98, 0.88);
    vec3 coolHighlight = vec3(0.96, 0.98, 1.04);
    return c * mix(warmShadow, coolHighlight, smoothstep(0.0, 0.8, l));
}

// Vignette effect
float cartoon_vignette(vec2 uv, float str, float aspect) {
    vec2 v = (uv - 0.5) * 2.0;
    v.y *= aspect;
    return 1.0 - smoothstep(0.5, 1.5, dot(v, v) * str);
}

// Apply all cartoon effects to final color
vec3 applyCartoonStyle(vec3 color, vec2 texCoord, float aspectRatio) {
    #ifdef CARTON_STYLE_ENABLED
        // Apply filmic curve (contrast)
        color = cartoon_filmicCurve(color, float(CARTOON_CONTRAST) * 0.1);
        
        // Adjust saturation
        color = cartoon_adjustSat(color, float(CARTOON_SATURATION) * 0.1);
        
        // Color grading
        color = cartoon_colorGrade(color);
        
        // Vignette
        float vigStr = float(CARTOON_VIGNETTE) * 0.08 + 0.6;
        color *= cartoon_vignette(texCoord, vigStr, aspectRatio);
    #endif
    
    return clamp(color, 0.0, 1.0);
}