const float oneMinusShoulder = 1.0 - SHOULDER_STRENGTH;

const float shoulderFactor = oneMinusShoulder * 3.0;
const float shoulderWhitePointFactor = oneMinusShoulder / (WHITE_POINT * WHITE_POINT);

// Luminance function
float getLuminance(in vec3 col){
    return dot(col, vec3(0.2126, 0.7152, 0.0722));
}

// Saturation function
vec3 saturation(in vec3 col, in float a){
    float luma = getLuminance(col);
    return (col - luma) * a + luma;
}

// Contrast function
vec3 contrast(in vec3 col, in float a){
    return (col - 0.5) * a + 0.5;
}



// Tonemap2
vec3 Tonemap2(in vec3 color){
    color *= 1.3;

    const float p = 2.9;
    color = pow(color, vec3(p));
    color = color / (1.0 + color);
    color = pow(color, vec3(1.0 / p));

    color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.0));

    color = pow(color, vec3(1.0 / 2.0));
    color = mix(color, color * color * (3.0 - 2.0 * color), vec3(0.1));
    color = pow(color, vec3(2.0));

    return color;
}
