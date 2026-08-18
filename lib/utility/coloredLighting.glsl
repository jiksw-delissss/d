struct LightData {
    vec3 lightColor;
    vec2 lmCoord;
};

LightData decodeLightCoord() {
    ivec2 rawLm = ivec2(gl_MultiTexCoord1.xy);

    int lsShort   = rawLm.x;
    int msShort   = rawLm.y;

    int red8      = (lsShort >> 0) & 0xFF;
    int green8    = (lsShort >> 8) & 0xFF;
    int skyLight4 = (msShort >> 0) & 0xF;
    int blue8     = (msShort >> 4) & 0xFF;
    int alpha4    = (msShort >> 12) & 0xF;

    LightData data;

    if (alpha4 == 0xF) {
        data.lmCoord.x  = floor(pow(max(max(red8, green8), blue8) * 0.00392156862745, 1.3) * 240.0);
        data.lightColor = pow(vec3(red8, green8, blue8) * 0.00392156862745, vec3(1.3)) / max(pow(max(max(red8, green8), blue8) * 0.00392156862745, 1.3), 0.00001);
        data.lmCoord.y  = float(skyLight4 << 4);
    } else {
        data.lightColor = blockLightColorDefault;
        data.lmCoord    = vec2(rawLm);
    }

    return data;
}

void correctedLightMap() {
    LightData data = decodeLightCoord();

    // Lightmap fix for mods
    #ifdef WORLD_CUSTOM_SKYLIGHT
        lmCoord = vec2(lightMapCoord(data.lmCoord.x), WORLD_CUSTOM_SKYLIGHT);
    #else
        lmCoord = lightMapCoord(data.lmCoord.xy);
    #endif

    blockLightColor = data.lightColor;
}
