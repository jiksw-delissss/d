// Reduced jitter offsets for minimal jittering
const vec2 offSetsTAA[8] = vec2[8](
    vec2(0.0625,-0.1875),
    vec2(-0.0625, 0.1875),
    vec2(0.3125, 0.0625),
    vec2(0.1875,-0.3125),
    vec2(-0.3125, 0.3125),
    vec2(-0.4375,-0.0625),
    vec2(0.1875,-0.4375),
    vec2(0.4375, 0.4375)
);

vec2 jitterPos(in float posW){
	return offSetsTAA[frameMod] * vec2(pixelWidth, pixelHeight) * posW;
}