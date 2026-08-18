/* --Main world/dimension settings-- */

/* This file allows custom macro settings for multiple worlds/dimensions,
allowing more compatibility for future worlds/dimensions and modded worlds/dimensions */

// Initial dimension id
#define WORLD_ID 0

// Enable if your world uses default shader lighting from the sun/moon
#define WORLD_LIGHT
// Enable sun/moon in your world. 1 for the standard sun and moon. 2 for the black hole.
#define WORLD_SUN_MOON 1
// Sun/moon size
#define WORLD_SUN_MOON_SIZE 0.125

// Force disable clouds
// #define FORCE_DISABLE_CLOUDS
// Force disable weather
// #define FORCE_DISABLE_WEATHER
// Force disable day cycle
// #define FORCE_DISABLE_DAY_CYCLE

// Enable aether particles in your world
// #define WORLD_AETHER
// Enable sky ground
#define WORLD_SKY_GROUND

// Use a sky light amount if your world has an undefined sky lighting environment like The End or the Nether
// #define WORLD_CUSTOM_SKYLIGHT 1.00

// Enable stars in your world
// Modified star visibility - stars only visible when dayCycle is between 1.5 and 2.0 (night phase)
#define WORLD_STARS toLinear(clamp((dayCycle - 1.5) * 4.0, 0.0, 1.0))

// If the world utilizes vanilla sky color
// #define WORLD_VANILLA_FOG_COLOR
// Enable if your world uses a specific world color that uses the vanilla fog color, overrides sky colors
// #define WORLD0_VANILLA_FOGCOLI 1.00 // Intensity value [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define FOG0_VERTICAL_DENSITY_D 0.080 // Vertical density falloff, larger means thinner fog at high altitudes, but thicker fog in low altitudes [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100 0.105 0.110 0.115 0.120 0.125 0.130 0.135 0.140 0.145 0.150 0.155 0.160 0.165 0.170 0.175 0.180 0.185 0.190 0.195 0.200 0.205 0.210 0.215 0.220 0.225 0.230 0.235 0.240 0.245 0.250 0.255 0.260 0.265 0.270 0.275 0.280 0.285 0.290 0.295 0.300 0.305 0.310 0.315 0.320 0.325 0.330 0.335 0.340 0.345 0.350 0.355 0.360 0.365 0.370 0.375 0.380 0.385 0.390 0.395 0.40 0.405 0.410 0.415 0.420 0.425 0.430 0.435 0.440 0.445 0.450 0.455 0.460 0.465 0.470 0.475 0.480 0.485 0.490 0.495 0.500]
#define FOG0_VERTICAL_DENSITY_N 0.020 // Vertical density falloff, larger means thinner fog at high altitudes, but thicker fog in low altitudes [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100 0.105 0.110 0.115 0.120 0.125 0.130 0.135 0.140 0.145 0.150 0.155 0.160 0.165 0.170 0.175 0.180 0.185 0.190 0.195 0.200 0.205 0.210 0.215 0.220 0.225 0.230 0.235 0.240 0.245 0.250 0.255 0.260 0.265 0.270 0.275 0.280 0.285 0.290 0.295 0.300 0.305 0.310 0.315 0.320 0.325 0.330 0.335 0.340 0.345 0.350 0.355 0.360 0.365 0.370 0.375 0.380 0.385 0.390 0.395 0.40 0.405 0.410 0.415 0.420 0.425 0.430 0.435 0.440 0.445 0.450 0.455 0.460 0.465 0.470 0.475 0.480 0.485 0.490 0.495 0.500]
#define FOG0_VERTICAL_DENSITY_T 0.040 // Vertical density falloff, larger means thinner fog at high altitudes, but thicker fog in low altitudes [0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.080 0.085 0.090 0.095 0.100 0.105 0.110 0.115 0.120 0.125 0.130 0.135 0.140 0.145 0.150 0.155 0.160 0.165 0.170 0.175 0.180 0.185 0.190 0.195 0.200 0.205 0.210 0.215 0.220 0.225 0.230 0.235 0.240 0.245 0.250 0.255 0.260 0.265 0.270 0.275 0.280 0.285 0.290 0.295 0.300 0.305 0.310 0.315 0.320 0.325 0.330 0.335 0.340 0.345 0.350 0.355 0.360 0.365 0.370 0.375 0.380 0.385 0.390 0.395 0.40 0.405 0.410 0.415 0.420 0.425 0.430 0.435 0.440 0.445 0.450 0.455 0.460 0.465 0.470 0.475 0.480 0.485 0.490 0.495 0.500]

#define FOG0_TOTAL_DENSITY 0.005 // Total density falloff, larger means thicker fog [0.001 0.002 0.003 0.004 0.005 0.010 0.015 0.020 0.025 0.030 0.035 0.040 0.045 0.050 0.055 0.060 0.065 0.070 0.075 0.80 0.085 0.090 0.095 0.100 0.105 0.110 0.115 0.120 0.125 0.130 0.135 0.140 0.145 0.150 0.155 0.160 0.165 0.170 0.175 0.180 0.185 0.190 0.195 0.200 0.205 0.210 0.215 0.220 0.225 0.230 0.235 0.240 0.245 0.250 0.255 0.260 0.265 0.270 0.275 0.280 0.285 0.290 0.295 0.300 0.305 0.310 0.315 0.320 0.325 0.330 0.335 0.340 0.345 0.350 0.355 0.360 0.365 0.370 0.375 0.380 0.385 0.390 0.395 0.40 0.405 0.410 0.415 0.420 0.425 0.430 0.435 0.440 0.445 0.450 0.455 0.460 0.465 0.470 0.475 0.480 0.485 0.490 0.495 0.500]

// For the shader to read
#define FOG_VERTICAL_DENSITY lerp(FOG0_VERTICAL_DENSITY_N, FOG0_VERTICAL_DENSITY_T, FOG0_VERTICAL_DENSITY_D, dayCycle)
#define FOG_TOTAL_DENSITY FOG0_TOTAL_DENSITY

// Day colors - REALISTIC VALUES
#define LIGHT0_DR 255 // Sunlight red [255]
#define LIGHT0_DG 230 // Sunlight green [230] - slightly less green for warm sunlight
#define LIGHT0_DB 200 // Sunlight blue [200] - less blue for warm tone
#define LIGHT0_DI 0.90

const vec3 lightDayColor = vec3(LIGHT0_DR, LIGHT0_DG, LIGHT0_DB) * (LIGHT0_DI * 0.00392156863);

// GRAY-BLUE NATURAL SKY COLORS
#define SKY0_DR 140   // Less red for more natural gray-blue
#define SKY0_DG 165   // Reduced green
#define SKY0_DB 205   // More gray-blue, less pure blue
#define SKY0_DI 0.60  // Slightly brighter to compensate for grayer tone

const vec3 skyDayColor = vec3(SKY0_DR, SKY0_DG, SKY0_DB) * (SKY0_DI * 0.00392156863);

// Night colors
#define LIGHT0_NR 45 // Red value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define LIGHT0_NG 105 // Green value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define LIGHT0_NB 150 // Blue value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define LIGHT0_NI 1.00 // Intensity value [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define NIGHT_SHADOW_INTENSITY 0.00 // Intensity for night shadows [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

const vec3 lightNightColor = vec3(LIGHT0_NR, LIGHT0_NG, LIGHT0_NB) * (LIGHT0_NI * 0.00392156863);
const vec3 lightNightShadowColor = vec3(LIGHT0_NR, LIGHT0_NG, LIGHT0_NB) * (NIGHT_SHADOW_INTENSITY * 0.00392156863);

#define SKY0_NR 0 // Red value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define SKY0_NG 30 // Green value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define SKY0_NB 120 // Blue value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define SKY0_NI 1.00 // Intensity value [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

const vec3 skyNightColor = vec3(SKY0_NR, SKY0_NG, SKY0_NB) * (SKY0_NI * 0.00392156863);

// Sunset/Sunrise colors (for smooth transitions)
#define LIGHT0_SR 255 // Sunset red - warm orange/red
#define LIGHT0_SG 140 // Sunset green
#define LIGHT0_SB 60  // Sunset blue
#define LIGHT0_SI 1.00 // Intensity value

const vec3 lightSunsetColor = vec3(LIGHT0_SR, LIGHT0_SG, LIGHT0_SB) * (LIGHT0_SI * 0.00392156863);

#define SKY0_SR 180 // Sunset sky red
#define SKY0_SG 90  // Sunset sky green
#define SKY0_SB 150 // Sunset sky blue - purple/blue mix
#define SKY0_SI 1.00 // Intensity value

const vec3 skySunsetColor = vec3(SKY0_SR, SKY0_SG, SKY0_SB) * (SKY0_SI * 0.00392156863);

// Twilight colors - NATURAL BLUE, NOT PURPLE
#define LIGHT0_TR 240 // Twilight sunlight red - warm orange
#define LIGHT0_TG 180 // Twilight sunlight green
#define LIGHT0_TB 120 // Twilight sunlight blue - orange tone
#define LIGHT0_TI 0.60 // Intensity value

const vec3 lightTwilightColor = vec3(LIGHT0_TR, LIGHT0_TG, LIGHT0_TB) * (LIGHT0_TI * 0.00392156863);

#define SKY0_TR 140   // Twilight sky red
#define SKY0_TG 160   // Twilight sky green  
#define SKY0_TB 200   // Twilight sky blue - BLUE, NOT PURPLE
#define SKY0_TI 0.60  // Intensity value

const vec3 skyTwilightColor = vec3(SKY0_TR, SKY0_TG, SKY0_TB) * (SKY0_TI * 0.00392156863);


// ====== FIXED TRANSITION LOGIC WITH SMOOTH BLENDING ======

// Sun and Moon color definitions for shader
#define SUN_COL_DATA_BLOCK lightDayColor
#define MOON_COL_DATA_BLOCK (LIGHT0_NI > 0.0 ? lightNightColor : lightNightShadowColor)

// dayCycle: 0.0-1.0 = night, 1.0-2.0 = day
// Simple smooth transition around dayCycle = 1.0
#define TRANSITION_CENTER 1.0
#define TRANSITION_WIDTH 0.2  // 0.2 = 10% of cycle on each side

// Calculate how far we are into the transition (0.0 = night, 1.0 = day)
#define TRANSITION_PROGRESS clamp((dayCycle - (TRANSITION_CENTER - TRANSITION_WIDTH)) / (2.0 * TRANSITION_WIDTH), 0.0, 1.0)

// Use smoothstep for smooth easing
#define DAY_BRIGHTNESS smoothstep(0.0, 1.0, TRANSITION_PROGRESS)

// Simple linear light transition
#define LIGHT_COLOR_DATA_BLOCK0 \
    mix(lightNightColor, lightDayColor, DAY_BRIGHTNESS)

#define LIGHT_COLOR_DATA_BLOCK1(S, M) \
    mix(M, S, DAY_BRIGHTNESS)

// Sky color - stays at day color during full day, uses twilight only during transition
#define SKY_COLOR_DATA_BLOCK \
    (DAY_BRIGHTNESS < 0.5 ? \
        mix(skyNightColor, skyTwilightColor, DAY_BRIGHTNESS * 2.0) : \
        mix(skyTwilightColor, skyDayColor, (DAY_BRIGHTNESS - 0.5) * 2.0))