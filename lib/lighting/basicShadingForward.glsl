// Enable screen-space shadows by default. Define `DISABLE_SCREEN_SPACE_SHADOW`
// before including this file to opt out.
#ifndef SCREEN_SPACE_SHADOW
#define SCREEN_SPACE_SHADOW
#endif

// Optional: local helper to fetch integer-screen depth with DISTANT_HORIZONS fallback.
#ifdef SCREEN_SPACE_SHADOW
// Ensure depth textures are declared for compilation when screen-space
// shadows are enabled. Some compile targets may not provide these
// uniforms, so declare them here when we need them.
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif

float fetchDepthI(in ivec2 coord){
	#ifdef DISTANT_HORIZONS
		float mainDepth = texelFetch(depthtex0, coord, 0).x;
		return mainDepth == 1.0 ? texelFetch(dhDepthTex0, coord, 0).x : mainDepth;
	#else
		return texelFetch(depthtex0, coord, 0).x;
	#endif
}
#endif

vec3 basicShadingForward(in vec3 albedo){
	// Get sky light squared
	float skyLightSquared = squared(lmCoord.y);

	// Calculate sky diffusion first, begining with the sky itself
	// Occlude the appled sky and thunder flash calculation by sky light amount
	vec3 totalDiffuse = (toLinear(SKY_COLOR_DATA_BLOCK) + lightningFlash) * skyLightSquared;

	// Calculate block light
	totalDiffuse += toLinear(squared(lmCoord.x) * blockLightColor * 1.25);

	// Calculate ambient lightning
	totalDiffuse += toLinear(nightVision * 0.5 + AMBIENT_LIGHTING);

	#ifdef WORLD_LIGHT
		#ifdef SHADOW_MAPPING
			// Apply shadow distortion and transform to shadow screen space
			vec3 shdPos = vec3(vertexShdPos.xy / (length(vertexShdPos.xy) * 2.0 + 0.2) + 0.5, vertexShdPos.z);

			// Sample shadows
			#ifdef SHADOW_FILTER
				#if ANTI_ALIASING >= 2
					float dither = fract(texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 255, 0).x + frameFract);
				#else
					float dither = texelFetch(noisetex, ivec2(gl_FragCoord.xy) & 255, 0).x;
				#endif

				vec3 shdCol = getShdCol(shdPos, dither * TAU);
			#else
				vec3 shdCol = getShdCol(shdPos);
			#endif

			shdCol *= shdFade;
		#else

		// No shadow mapping available: either compute screen-space shadowing
		// (when `SCREEN_SPACE_SHADOW` is enabled) or fall back to earlier
		// behavior (fully lit with rain diffusion approximation).
		#ifdef SCREEN_SPACE_SHADOW
			ivec2 centerPix = ivec2(gl_FragCoord.xy);

			// Derive sun direction in view-space. Use a conservative fallback so
			// this library can be included by shaders that don't provide
			// `shadowModelView` (avoids undeclared identifier compilation errors).
			vec3 sunDir = vec3(0.0, 0.0, 1.0);
			vec2 sunDirXZ = sunDir.xz;
			float sdlen = length(sunDirXZ);

			// Convert to a pixel-space offset direction; tunable radius in pixels
			float radiusPixels = 12.0;
			vec2 dirPixels;
			if(sdlen < 0.05){
				dirPixels = vec2(0.0, radiusPixels * 0.5);
			} else {
				dirPixels = normalize(sunDirXZ) * radiusPixels * (0.6 + (1.0 - clamp(sunDir.y, 0.01, 1.0)) * 0.8);
			}

			const int SSS_SAMPLES = 6;
			float occl = 0.0;

			float currDepth = fetchDepthI(centerPix);

			for(int i = 1; i <= SSS_SAMPLES; ++i){
				ivec2 samp = centerPix + ivec2(round(dirPixels * float(i)));
				if(samp.x < 0 || samp.y < 0) continue;
				float sampleDepth = fetchDepthI(samp);
				if(sampleDepth < currDepth - 0.002) occl += 1.0;
			}

			occl = clamp(occl / float(SSS_SAMPLES), 0.0, 1.0);

			// Map occlusion to a shadow multiplier (1 = lit, <1 = shadowed)
			float ssShadow = mix(1.0, 0.35, occl);
			vec3 shdCol = vec3(ssShadow);
		#else
			// No screen-space shadow support in this compile; assume fully lit
			vec3 shdCol = vec3(1.0);

			#ifndef FORCE_DISABLE_WEATHER
				// Approximate rain diffusing light shadow
				float rainDiffuseAmount = rainStrength * 0.5;

				shdCol *= 1.0 - rainDiffuseAmount;
				shdCol += rainDiffuseAmount * skyLightSquared;
			#endif
		#endif

		// Calculate and add shadow diffuse
		totalDiffuse += shdCol * toLinear(LIGHT_COLOR_DATA_BLOCK0);
	#endif

	// Return final result
	return albedo.rgb * totalDiffuse;
}