/// -------------------------------- /// Voxel RT integration /// -------------------------------- ///
// Ported from timetravelbeard's Voxelizing Tutorial. This uses the voxel buffer for
// ray traced reflections instead of screen space reflections.

// #define RAYTRACING_DEBUG_VIEW // Optional: leave this off for real SDV integration.
// #define VOXEL_RT_LIGHTING // Disabled: using RT reflections instead.
#define VOXEL_RT_REFLECTIONS // Enables ray-traced reflections using voxelized terrain
#define VOXEL_AREA 128 // Match the tutorial’s stable player-space voxel volume. [128 256]
#define VOXEL_SUBDIV 1 // Voxel cells per block edge. 1 = old behavior (1 voxel/block, blocky). Higher = finer shape but shrinks the covered world radius (radius = VOXEL_AREA / (2 * VOXEL_SUBDIV) blocks) since the image size is unchanged. [1 2 4]
#define RT_STEPS 100 // Keep the tutorial’s trace budget for stable DDA hits. [150 200]
// #define VOXEL_REJECT_ISOLATED_HITS // Ignore a hit voxel with no horizontal neighbors. Off by default: this also throws out legitimate sparse foliage (a lone flower/grass tuft has no solid neighbors by design), which now voxelizes on purpose via the corner-write fallback in shadow_cutout.glsl/shadow_block.glsl. Turn on only if you bring back stray-artifact issues and don't mind losing isolated non-blocky blocks from reflections.

/// -------------------------------- /// Post /// -------------------------------- ///

#define OUTLINES 2 // Enables outlines. Set to standard for classic outlined blocks, or Dungeons for Dungeons/SDGP styled outlines. [0 1 2]
#define OUTLINE_BRIGHTNESS 1.00 // Outline brightness. Set it to -1 for black outlines, or 1 to highlighted outlines. [-1.00 -0.95 -0.90 -0.85 -0.80 -0.75 -0.70 -0.65 -0.60 -0.55 -0.50 -0.45 -0.40 -0.35 -0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define OUTLINE_PIXEL_SIZE 1 // Outline pixel size. Adjust to change the thickness of the outlines [1 2 4 8 16 32 64]

// #define RETRO_FILTER // Enable retro filter. Works best at low render quality.

#define ANTI_ALIASING 2 // Enables anti-aliasing. FXAA is fast and works with screenshot sizes. TAA is slower, doesn't work with custom screenshots, but smooths noise. Disable anti-aliasing on your shader menu before using this feature! [0 1 2 3]
// #define SHARPEN_FILTER // Enables image sharpening. Use this with AA on if the image appears blurry.

/// -------------------------------- /// Camera /// -------------------------------- ///

// #define DOF // Enables depth of field. Enables anti-aliasing for better results.
#define DOF_STRENGTH 1 // Depth of field strength. [1 2 3 4]

// #define CHROMATIC_ABERRATION // Enable chromatic abberation.
#define ABERRATION_PIXEL_SIZE 4 // Chromating abberation length. Increase for stronger effects. [1 2 4 8 16]

#define BLOOM // Enables bloom.
#define BLOOM_STRENGTH 0.75 // Bloom brightness [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

#define LENS_FLARE // Enables lens flare.
#define LENS_FLARE_STRENGTH 1.00 // Lens flare intensity. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

// #define VIGNETTE // Enables vignette
#define VIGNETTE_STRENGTH 1.00 // Vignette intensity [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

// #define MOTION_BLUR // Enable motion blur.
#define MOTION_BLUR_STRENGTH 1.00 // Motion blur strength. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 3.00 4.00 5.00 6.00 7.00 8.00 9.00 10.00 11.00 12.00 13.00 14.00 15.00 16.00]

/// -------------------------------- /// Cartoon/Cel Shading /// -------------------------------- ///

#define CARTON_STYLE_ENABLED // Enables cartoon/cel shading style
#define CEL_LIGHTING_STEPS 4 // Cel shading bands (2-6) [2 3 4 5 6]
#define CEL_THRESHOLD 65 // Band transition softness (0=hard 100=smooth) [0 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define CARTOON_CONTRAST 12 // Cartoon contrast strength (5-20) [5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20]
#define CARTOON_SATURATION 13 // Cartoon saturation level (5-25) [5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
#define CARTOON_VIGNETTE 2 // Cartoon vignette darkness (0-10) [0 1 2 3 4 5 6 7 8 9 10]

// Outline settings specific to cartoon style (overrides regular outlines when cartoon style is enabled)
#define CARTOON_OUTLINE_ENABLE // Enables ink outlines
#define CARTOON_OUTLINE_THICKNESS 1 // Outline width in pixels [1 2 3]

/// -------------------------------- /// Tonemapping /// -------------------------------- ///

#define CONTRAST 1.00 // Contrast, controls color contrast [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define SATURATION 1.00 // Saturation, controls how much color saturation [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define WHITE_POINT 2.0 // Tonemap whitepoint [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define SHOULDER_STRENGTH 0.00 // Tonemap shoulder strength [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

// #define AUTO_EXPOSURE // Enables real time auto exposure. Does not work with custom Optifine screenshot resolutions!
#define AUTO_EXPOSURE_SPEED 1.00 // Auto exposure temporal speed. Changes how fast or slow the auto exposure will adjust to the screen's exposure. Smaller values means slower, bigger values means faster. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define EXPOSURE 1.00 // Exposure, controls color exposure [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define MINIMUM_EXPOSURE 0.10 // Min auto exposure value. Lower values may increase exposure of dark scenes if auto exposure is on. [0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90]

#define TINT_R 255 // Red tint value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define TINT_G 250 // Green tint value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define TINT_B 240 // Blue tint value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]

/// -------------------------------- /// Lighting /// -------------------------------- ///

#define SHADOW_MAPPING // Enables shadow mapping. Disable to use fake shadows with lightmap.
#define SHADOW_FILTER // Enables soft shadow filtering, if enabled shadows will appear softer by using noise. May impact performance.
#define SHADOW_COLOR // Enables shadow color from colored transparent objects.
#define USE_LIGHTMAP // Enables lightmap-based attenuation of reflections in shadowed areas.
#define SHADOW_TERRAIN_CAMERA_CULL
// Fast performance mode: enables lower-quality, faster lighting & shadow defaults
// Define `FAST_LIGHTING` to prioritize FPS. This mode keeps visual correctness
// but reduces sample counts, roughness work and volumetric tracing.
// Toggle this on to improve FPS on slower GPUs.
#define FAST_LIGHTING

// When FAST_LIGHTING is enabled, shaders will use these reduced settings.
// Lower numbers = faster but lower quality.
#ifdef FAST_LIGHTING
	#define FAST_SHADOW_SAMPLES 4 // [4 8 16 32]
	#define FAST_SHADOW_PENUMBRA 0 // [1 0]
	#define FAST_VOLUMETRIC_STEPS 1 // [1 4 8 16]
	#define FAST_SHADING_SMOOTHNESS_THRESHOLD 0.02 // Early-out smoothness threshold
	#define FAST_DISABLE_NOISE 1 // []
#endif



#define ENTITY_SHADOWS // Enables entity shadows.
#define BLOCK_ENTITY_SHADOWS // Enables block entity shadows.

const float sunPathRotation = 30.0; // Light path angle. This also affects sky angle. [-60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0]

#define UNDERWATER_CAUSTICS 1 // Enables underwater caustics. Shadow color must be enabled! [0 1 2]
#define SSAO // Enables screenspace ambient occlusion.
#define AMBIENT_LIGHTING 0.01 // Overall ambient lighting value. Set to zero for realistic approach with SSGI enabled. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50]

/// -------------------------------- /// Ray tracing settings /// -------------------------------- ///

#define SSGI // Enables World-Space RSM Global Illumination. Requires Shadow Mapping + Shadow Color.
#define WGI_DEBUG_COLORS // DEBUG: Show pure GI bounced colors (disable for normal rendering)

// ── World-Space GI tunables ──────────────────────────────────────────────────
#define WGI_SAMPLES 8      // VPL samples per pixel [4 8 12 16]
#define WGI_RADIUS 0.15    // RSM sampling radius in shadow-UV space [0.05 0.10 0.15 0.25 0.40]
#define WGI_STRENGTH 1.2   // GI intensity multiplier [0.5 1.0 1.2 2.0 3.0]
#define WGI_MAX_DIST 20.0  // Max world-space bounce distance in blocks [8 16 20 32 64]


// SEUS-style GI configuration
#define GI_QUALITY 1.0 // Number of GI samples. More samples=smoother GI. High performance impact! [0.5 1.0 2.0]
#define GI_RADIUS 1.0 // How far indirect light can spread. Can help to reduce artifacts with low GI samples. [0.5 0.75 1.0 1.5 2.0]
#define GI_SAMPLES 16 // Base sample count per direction [4 8 16 32]

// ─────────────────────────────────────────────────────────────────────────────
#define PREVIOUS_FRAME // Reads previous frame buffer colors allowing SSR or SSGI to have infinite bounces of light. Impacts performance!
#define SSR // Enables screen space global reflections. May improve the reflections of smooth objects using PBR.
#define ENTITIES

// Screen Space Colored Light (SSCL) - adds colored light from emissive surfaces on screen


// Ultra low quality, super-fast SSR mode for maximum FPS.
// When enabled this will drastically reduce ray march work and apply a cheap wide blur
// to produce very smooth, low-detail reflections suitable for high-FPS gameplay.
#define LOW_QUALITY_SMOOTH_SSR

// Tuning for the low quality mode (change in this file to tune FPS/quality):
#ifdef LOW_QUALITY_SMOOTH_SSR
	#define LOW_QUALITY_SSR_STEPSCALE 8.0
	#define LOW_QUALITY_SSR_BLUR_MIN 4.0
	#define LOW_QUALITY_SSR_BLUR_MAX 10.0
#endif

// Raytracer steps. Lower values = faster but coarser results. Use 4 for max speed.
#define RAYTRACER_STEPS 4 // Raytracer steps. Increasing may improve quality and demand more performance. [0 2 4 8 16 32 64 128]
// Disable binary refinement for best performance in low quality mode
#ifdef LOW_QUALITY_SMOOTH_SSR
	#define RAYTRACER_BISTEPS 0
#else
	#define RAYTRACER_BISTEPS 4 // Raytracer binary refinement steps. Improves quality especially when using a low step count. Balancing the values may be necessary for performance.  [0 2 4 6 8]
#endif

#define USE_SDF_RAYTRACER
#define USE_REFLECTION_BLOCK_COORD
#define ROUGH_REFLECTIONS // Enables rougher objects to have rougher reflections. May show weird artifacts, but some AA might fix it.
#define PREVIOUS_FRAME // Reads previous frame buffer colors alowing SSR or SSGI to have infinite bounces of light. Impacts performance!

/// -------------------------------- /// Atmospherics /// -------------------------------- ///

#define WORLD_LIGHT // Enables sun and moon in the sky.
#define WORLD_SUN_MOON 0 // Enables sun and moon in sky reflections. [0 1]
#define WORLD_SUN_MOON_SIZE 1 // Size of the sun and moon in the sky.
#define SUN_MOON_TYPE 0 // Changes sun and moon type [0 1 2]
#define SUN_MOON_INTENSITY 16 // The sun or moon's intensity. Also affects specular reflections. [0 1 2 3 4 5 6 7 8]

#define VOLUMETRIC_LIGHTING // Enables volumetric lighting.
#define VOLUMETRIC_LIGHTING_STRENGTH 0.50 // The strength of volumetric lighting, set it to zero to disable it [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define BORDER_FOG // Enables border fog to cover world edges
#define GROUND_FOG_STRENGTH 0.50 // The strength of mist/ground fog. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SKYBOX_BRIGHTNESS 1.00 // Sky box brightness. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define NIGHT_SKY_R 0 // Night sky red value [0 255]
#define NIGHT_SKY_G 0 // Night sky green value [0 255]
#define NIGHT_SKY_B 0 // Night sky blue value [0 255]
#define NIGHT_LIGHT_R 255 // Night light red value [0 255]
#define NIGHT_LIGHT_G 255 // Night light green value [0 255]
#define NIGHT_LIGHT_B 255 // Night light blue value [0 255]

/// -------------------------------- /// Cloud settings /// -------------------------------- ///

#define CLOUD_TYPE 2 // Changes cloud type. [0 1 2]
#define DOUBLE_LAYERED_CLOUDS // Adds another layer of clouds (works on both vanilla and shader clouds), may use up performance.
#define DYNAMIC_CLOUDS // Makes clouds more dynamic and allows weather to affect it. (affects on both vanilla and story mode clouds).
#define FADE_SPEED 0.10 // Cloud fade speed [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00 3.05 3.10 3.15 3.20 3.25 3.30 3.35 3.40 3.45 3.50 3.55 3.60 3.65 3.70 3.75 3.80 3.85 3.90 3.95 4.00]
#define SECOND_CLOUD_HEIGHT 128.0 // 2nd layer cloud height, if double vanilla clouds is on [0.0 4.0 8.0 12.0 16.0 20.0 24.0 28.0 32.0 36.0 40.0 44.0 48.0 52.0 56.0 60.0 64.0 68.0 72.0 76.0 80.0 84.0 88.0 92.0 96.0 100.0 104.0 108.0 112.0 116.0 120.0 124.0 128.0 132.0 136.0 140.0 144.0 148.0 152.0 156.0 160.0 164.0 168.0 172.0 176.0 180.0 184.0 188.0 192.0 196.0 200.0 204.0 208.0 212.0 216.0 220.0 224.0 228.0 232.0 236.0 240.0 244.0 248.0 252.0 256.0]


#define VOLUMETRIC_CLOUD_STEPS 24 // True 3D cloud steps. More = better quality, more cost. [16 24 32 64 128]
#define VOLUMETRIC_CLOUD_DEPTH 16.0 // Cloud tower height multiplier (×6 = slab metres). 16=96m tall towers. [4.0 8.0 12.0 16.0 20.0 24.0 32.0 40.0]

#define SKYBOX_CLOUD_STEPS 16 // Story mode clouds steps. Increasing may improve quality and demand more performance. [16 32 64 128 256]
#define SKYBOX_CLOUD_DEPTH 0.08 // Determines the story mode clouds' thickness. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

/// -------------------------------- /// World /// -------------------------------- ///

#define TERRAIN_ANIMATION // Enables terrain waving animation.
#define FOLIAGE_TOUCH // Enables interactive foliage touch effect (works independently of terrain animation).
#define WATER_ANIMATION // Enables water waving animation.
#define WEATHER_ANIMATION // Enables rain waving animation.

#define TIMELAPSE_MODE 2 // Enable timelapse mode. This smoothens the transition of animations of the sky, the foliage waving etc according to current world time instead of frame time. Set to fragment for water normals and sky only and full for the water normals, sky, and waves. This feature does not work on vanilla clouds, skybox, and the sun and moon. [0 1 2]

#define WIND_SPEED 1.00 // Adjust wind speed. Affects plants, swinging objects, and weather. Increases the animation speed. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00 3.05 3.10 3.15 3.20 3.25 3.30 3.35 3.40 3.45 3.50 3.55 3.60 3.65 3.70 3.75 3.80 3.85 3.90 3.95 4.00 8.00 16.00]
#define CURRENT_SPEED 1.00 // Adjust liquid and under water flow speed. Affects underwater plants and liquids. Increases the animation speed. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00 3.05 3.10 3.15 3.20 3.25 3.30 3.35 3.40 3.45 3.50 3.55 3.60 3.65 3.70 3.75 3.80 3.85 3.90 3.95 4.00 5.00 6.00 8.00 12.00 16.00 32.00 64.00 128.00 256.00 512.00 1024.00 2048.00 4096.00]

#define WIND_FREQUENCY 1.00 // Adjust wind frequency. Affects plants, swinging objects, and weather. Increases the animation change frequency. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00 3.05 3.10 3.15 3.20 3.25 3.30 3.35 3.40 3.45 3.50 3.55 3.60 3.65 3.70 3.75 3.80 3.85 3.90 3.95 4.00]
#define CURRENT_FREQUENCY 1.00 // Adjust liquid and under water flow frequency. Affects underwater plants and liquids. Increases the animation change frequency. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00 2.05 2.10 2.15 2.20 2.25 2.30 2.35 2.40 2.45 2.50 2.55 2.60 2.65 2.70 2.75 2.80 2.85 2.90 2.95 3.00 3.05 3.10 3.15 3.20 3.25 3.30 3.35 3.40 3.45 3.50 3.55 3.60 3.65 3.70 3.75 3.80 3.85 3.90 3.95 4.00]

// #define WORLD_CURVATURE // Enable world curvature
#define WORLD_CURVATURE_SIZE 256 // World curvature size [-4096 -2048 -1024 -512 -256 -128 128 256 512 1024 2048 4096]

/// -------------------------------- /// PBR /// -------------------------------- ///

#define PBR_MODE 1 // Enables PBR. Integrated PBR depends on the vanilla albedo textures to map out the materials. Resource PBR uses your resource packs' PBR, if available. Resource PBR requires latest LabPBR version! [0 1 2]
#define SPECULAR_HIGHLIGHTS // Enables specular highlight. Specular highlights are the approximate reflections of the sun.
#define ENVIRONMENT_PBR // Enables enviroment materials. Environment materials affects your surrounding according to your environment such as rain.
#define SUBSURFACE_SCATTERING // Enables subsurface scattering. 
#define EMISSIVE_INTENSITY 8 // Emissive maps intensity. Does not affect lightmaps and requires PBR on. [2 4 8 16 32]
#define NORMAL_STRENGTH 1.00 // Normal map strength. Effective only if PBR is on with the RP normals, and slope normals is off. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

/// -------------------------------- /// Specular tuning /// -------------------------------- ///
// Tweak these to control how bright sun-speculars appear on different object types.
// Lower values make reflections less bright.
#define GLOBAL_SPECULAR_SCALE 1.0 // Global multiplier for added specular terms. [0.25 0.5 0.75 1.0]
#define SUN_SPECULAR_MIN_SMOOTHNESS 0.18  // larger = softer/wider highlight
#define SUN_SPECULAR_STRENGTH       1000.0   // overall brightness multiplier

// Terrain sun highlight tuning
#define TERRAIN_SUN_SPECULAR_INTENSITY 0.030 // Base intensity for terrain Blinn-Phong highlight. [0.00 0.02 0.04 0.06]
#define TERRAIN_BP_WEIGHT 0.01 // Weight between BRDF and Blinn-Phong contribution on terrain. [0.0..1.0]

// Hand / held item reflection tuning
#define HAND_REFLECT_INTENSITY 0.40 // Intensity for hand-held item added specular. [0.0..1.0]

// Entity / armor reflection tuning
#define ENT_REFLECT_INTENSITY 0.30 // Intensity for entity/armor added specular. [0.0..1.0]

// #define SLOPE_NORMALS // Enables slope normals. Disable this feature if you're using a high resolution pack with normal maps. Thanks @Null!
// #define DIRECTIONAL_LIGHTMAPS // Enables directional lightmaps. Effective only if auto generated normals or normal maps from PBR is enabled.
#define DIRECTIONAL_LIGHTMAP_STRENGTH 1.00 // Directional lightmap strength. Effective if directional lightmaps is enabled. [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

/// -------------------------------- /// iPBR settings /// -------------------------------- ///

// #define NORMAL_GENERATION // Enables normal generation. Disabled when LabPBR is on. Works mostly on vanilla resource packs.
#define NORMAL_GENERATION_RESOLUTION 128 // Auto generated normal resolution. Minor effects to performance. [16 32 64 128 256 512 1024]

/// -------------------------------- /// Water material settings /// -------------------------------- ///

#define WATER_ADVANCED_COLORING // Enables advanced multi-tier water coloring system with time-of-day and environmental effects
#define WATER_COLOR_DEPTH_SCALE 0.06 // Water depth color scale - higher values make color transitions happen faster [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10]
#define WATER_COLOR_SATURATION 1.00 // Water color saturation multiplier [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30]
#define WATER_WEATHER_INFLUENCE 1.00 // How much rain/weather affects water color [0.00 0.25 0.50 0.75 1.00 1.25 1.50]
#define WATER_FRESNEL_INFLUENCE 0.50 // Fresnel effect on water color saturation [0.00 0.25 0.50 0.75 1.00]

#define WATER_NOISE // Enables water noise. Varies the water brightness by noise similar to SDGP.
#define WATER_BRIGHTNESS 1.00 // Water brightness, lower values mean deeper colors [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]

// Controls the overall brightness of underwater caustic highlights.
// Increased to better match the brightness in the provided reference image.
// Tweak this value if you want stronger/weaker caustics (e.g. 2.75 for very bright).
#define WATER_CAUSTIC_BRIGHTNESS 0.5 // [0.5 0.75 1.0 1.12 1.25 1.5 1.75 2.0 2.25 2.5]

#define WATER_NORMAL // Enables water normals
#define WATER_BLUR_SIZE 8.0 // Water normal map blur size, smaller means more defined waves, larger means smoother waves [0.0 0.1 1.0 2.0 4.0 8.0 16.0 32.0 64.0]
#define WATER_DEPTH_SIZE 0.5 // The normal map depth of the waves, the smaller the more depth it has [0.00 0.125 0.25 0.5 1.0 2.0]
#define WATER_REFLECTION_NORMAL_SCALE 0.4 // Strength of water normal slope for reflection/parallax 
#define DH_WATER_BLUR_SIZE 8.0 // Distant Horizons water normal map blur size [0.0 0.1 1.0 2.0 4.0 8.0 16.0 32.0 64.0]
#define DH_WATER_DEPTH_SIZE 0.5 // Distant Horizons water normal map depth size [0.00 0.125 0.25 0.5 1.0 2.0]
#define WATER_TILE_SIZE 16 // Tile size of the water [4 8 16 24 32 64 128]

// Screen-space refraction and chromatic dispersion controls
#define WATER_REFRACTION_STRENGTH 1.1 // Base UV offset strength for water refraction [0.00 0.01 0.02 0.03 0.04]
#define WATER_CHROMA_STRENGTH 0.5 // Chromatic dispersion strength (0 = off, ~0.3-0.6 = visible)
// Underwater volumetric density multiplier. Larger values make underwater fog/volumetrics much denser.
// Increase this to make water appear thicker; typical values: 6-12.
#ifndef UNDERWATER_VOLUMETRIC_BOOST
#define UNDERWATER_VOLUMETRIC_BOOST 7.0  // Adjust this value (2.0 = 2x stronger)
#endif
#define UNDERWATER_FOG_MULT 4.45 // reduced to make underwater fog less dense

// Default underwater fog color (green-blueish). Tweak to taste.
const vec3 UNDERWATER_FOG_COLOR = vec3(0.0, 0.10, 0.8);

#define WATER_STYLIZE_ABSORPTION // Enables stylized water absorption. Changes water color based on depth.
#define WATER_FOAM // Enables water foam. Appears on the sides of most solid objects, including entities.
// #define WATER_FLAT // Enables flat water albedo.

/// -------------------------------- /// Water physical absorption (Eclipse port) /// -------------------------------- ///

// Water absorption coefficients — higher = more absorbed (colour disappears faster with depth)
// R is absorbed most → water looks blue/green at depth
#define Water_Absorb_R 0.392389 // [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.2 1.4 1.6 1.8 2.0]
#define Water_Absorb_G 0.108329 // [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.2 1.4 1.6 1.8 2.0]
#define Water_Absorb_B 0.0660636 // [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.2 1.4 1.6 1.8 2.0]

// Suspended dirt/particles in water — adds murky scatter colour
#define Dirt_Amount 0.1 // [0.0 0.01 0.02 0.03 0.05 0.07 0.1 0.15 0.2 0.3 0.4 0.5 0.7 1.0 1.5 2.0]
#define Dirt_Absorb_R 0.68 // [0.0 0.02 0.04 0.06 0.08 0.1 0.2 0.3 0.4 0.5 0.6 0.68 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define Dirt_Absorb_G 0.40 // [0.0 0.02 0.04 0.06 0.08 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define Dirt_Absorb_B 0.38 // [0.0 0.02 0.04 0.06 0.08 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0]
#define Dirt_Scatter_R 0.6 // [0.01 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 0.99]
#define Dirt_Scatter_G 0.39 // [0.01 0.05 0.1 0.2 0.3 0.39 0.4 0.5 0.6 0.7 0.8 0.9 0.99]
#define Dirt_Scatter_B 0.39 // [0.01 0.05 0.1 0.2 0.3 0.39 0.4 0.5 0.6 0.7 0.8 0.9 0.99]

// Minimum water absorbance depth (blocks). -1 = auto based on light level.
#define MINIMUM_WATER_ABSORBANCE -1 // [-1 0 1 2 3 4 5 6 7 8 10 12 15 20 25 30 40 50]

// Caustics
#define WATER_CAUSTICS_BRIGHTNESS 1.0 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.5 1.75 2.0 3.0 4.0 5.0]
#define WATER_CAUSTICS_POWER 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0]
#define PATCHY_WAVE_BLEND 1.0 // [0.0 0.25 0.5 0.75 1.0]
#define WATER_WAVE_SPEED 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define WATER_VERTEX_WAVE_SPEED 1.0 // Speed multiplier for the vertex water waves (actual geometry displacement) [0.0 0.1 0.25 0.5 0.75 1.0 1.25 1.5 2.0 3.0 4.0]

// Bloomy underwater fog strength
#define UNDERWATER_BLOOMY_FOG 1.0 // [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 3.0 4.0 6.0]

/// -------------------------------- /// Lava material settings /// -------------------------------- ///

#define LAVA_BRIGHTNESS 1.00 // Lava brightness, lower values mean darker colors [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define LAVA_NOISE // Enables lava noise. Varies the lava brightness by noise similar to Minecraft Dungeons.
#define LAVA_TILE_SIZE 16 // Tile size of the lava [4 8 16 24 32]

/// -------------------------------- /// Sculk material settings /// -------------------------------- ///

#define SCULK_BRIGHTNESS 1.00 // Lava brightness, lower values mean darker colors [0.00 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.20 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.40 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.50 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.60 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.80 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.90 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00]
#define SCULK_NOISE // Enables sculk noise. Varies the sculk emissives by noise.
#define SCULK_TILE_SIZE 8 // Tile size of the lava [2 4 8 16 24]

/// -------------------------------- /// Parallax occlussion settings /// -------------------------------- ///

// #define PARALLAX_OCCLUSION // Enables parallax occlusion. Requires LabPBR on and a resource pack with LabPBR enabled materials.
#define PARALLAX_DEPTH 0.25 // Parallax occlusion depth strength. Increase for more depth. [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50]
#define PARALLAX_STEPS 128 // Parallax occlusion step ammount. Increase for improved POM quality. [16 32 64 128 256 512]

#define PARALLAX_SHADOW // Enables parallax self shadowing.
#define PARALLAX_SHADOW_STEPS 32 // Parallax self shadowing step ammount. Increase for improved self shadowing quality. [16 32 64 128 256 512]

/// -------------------------------- /// Configuration /// -------------------------------- ///
#define BLOCKLIGHT_R 255 // Red value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define BLOCKLIGHT_G 240 // Green value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define BLOCKLIGHT_B 210 // Blue value [3 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 93 96 99 102 105 108 111 114 117 120 123 126 129 132 135 138 141 144 147 150 153 156 159 162 165 168 171 174 177 180 183 186 189 192 195 198 201 204 207 210 213 216 219 222 225 228 231 234 237 240 243 246 249 252 255]
#define BLOCKLIGHT_I 1.00 // Intensity value [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
const vec3 blockLightColorDefault = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B) * (BLOCKLIGHT_I * 0.00392156863);
#define COLORED_LIGHT_ENABLED
/// -------------------------------- /// Secret settings /// -------------------------------- ///

#define COLOR_MODE 0 // Albedo color mode. White mode makes everything white. Black mode makes everything black. Foliage mode shows only foliage colors. Keeps materials on. [0 1 2 3]
#define NOISE_SPEED 8 // The speed in which the noise randomises each frame. Useful for TAA. This effect is visible only when TAA is enabled. [2 4 8 16 32]

/// -------------------------------- /// Physics mod settings /// -------------------------------- ///

// Note to self: I absolutely want all of the variables below this text to be all macros to follow the style guideline

#define PHYSICS_OCEAN_SUPPORT // Enables physics mod ocean support

const int PHYSICS_ITERATIONS_OFFSET = 13;

const float PHYSICS_DRAG_MULT = 0.048;
const float PHYSICS_XZ_SCALE = 0.035;
const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
const float PHYSICS_W_DETAIL = 0.75;
const float PHYSICS_FREQUENCY = 6.0;
const float PHYSICS_SPEED = 2.0;
const float PHYSICS_WEIGHT = 0.8;
const float PHYSICS_FREQUENCY_MULT = 1.18;
const float PHYSICS_SPEED_MULT = 1.07;
const float PHYSICS_ITER_INC = 12.0;
const float PHYSICS_NORMAL_STRENGTH = 0.6;

/// -------------------------------- /// Misc /// -------------------------------- ///

// For the shader loaders to detect the "phantom" options

#ifdef SHARPEN_FILTER
#endif

#ifdef LENS_FLARE
#endif

#ifdef ENTITY_SHADOWS
#endif

#ifdef BLOCK_ENTITY_SHADOWS
#endif

#ifdef VOLUMETRIC_LIGHTING
#endif

#ifdef SPECULAR_HIGHLIGHTS
#endif

#ifdef ENVIRONMENT_PBR
#endif

#ifdef NORMAL_GENERATION
#endif

#ifdef DIRECTIONAL_LIGHTMAPS
#endif

#ifdef WATER_NORMAL
#endif

#ifdef PARALLAX_SHADOW
#endif

// Precalculated constants

// Sun and moon intensity squared
const float sunMoonIntensitySqrd = 1.0;

// Sky box intensity squared
const float skyBoxIntensitySqrd = SKYBOX_BRIGHTNESS * SKYBOX_BRIGHTNESS;

// Sky box brightness squared
const float skyBoxBrightnessSqrd = SKYBOX_BRIGHTNESS * SKYBOX_BRIGHTNESS;

// World curvature size inverse
const float worldCurvatureInv = 1.0 / WORLD_CURVATURE_SIZE;

// Water tile size inverse
const float waterTileSizeInv = 1.0 / WATER_TILE_SIZE;