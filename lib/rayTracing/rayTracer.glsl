const uint rayTraceSteps = uint(RAYTRACER_STEPS);
const uint rayTraceBiSteps = uint(RAYTRACER_BISTEPS);

// Raytracer steps inverse
const float rayTracerStepsInv = 1.0 / RAYTRACER_STEPS;

// Binary refinement to improve sampled quality by stepping back and forth until it is closer to the actual result
vec2 binaryRefinement(in vec3 screenRayPos, in vec3 screenRayDir, in float sampledDepth, in bool intersection){
	// Reuse stored sampled depth and intersection to use 1 less depth sample
	for(uint i = 1u; i <= rayTraceBiSteps; i++){
		// Refine ray direction
		screenRayDir *= 0.5;
		screenRayPos += intersection ? -screenRayDir : screenRayDir;

		// Return early if we're on the last iteration
		if(i == rayTraceBiSteps) return screenRayPos.xy;

		// Get current texture depth (uses getDepthTex which handles DH layers)
		sampledDepth = getDepthTex(ivec2(screenRayPos.xy));
		// Check intersection
		intersection = sampledDepth <= screenRayPos.z;
	}

	// Alas, the ray has reached the end of its journey :,)
	return screenRayPos.xy;
}

// SEUS-style screen-space reflection trace adapted from the variant you provided.
// Preserves the shared SDV API (`vec3(rayHitPixel, 1.0)` or `vec3(0.0)`) while
// improving stability and DH compatibility.
vec3 rayTraceScene(in vec3 screenPos, in vec3 viewPos, in vec3 rayDir, in float dither){
	// Avoid degenerate rays and trivial self-reflections
	if(length(rayDir) < 1e-5) return vec3(0.0);

	// Normalize marching direction in view-space
	vec3 dir = normalize(rayDir);

	// If the ray points behind the camera (worse-case), skip
	if(dir.z >= 0.0) return vec3(0.0);

	// Tunable parameters (tradeoff: accuracy vs performance)
	float baseStep = 1.0; // initial step in view-space units
	const int MAX_STEPS = 164;
	const int MAX_REFINES = 11;

	// Start marching from a small offset to avoid immediate self-hit
	vec3 stepVec = dir * baseStep;
	vec3 currPos = viewPos + stepVec;
	vec3 prevPos = viewPos;
	vec2 finalSamplePos = vec2(-1.0);
	int refinements = 0;
	int stepsDone = 0;

	for(int i = 0; i < MAX_STEPS; ++i){
		// Bounds check in view-space distance
		if(-currPos.z > borderFar * 1.5 || -currPos.z < 0.0) break;

		// Project to screen
		vec4 clip = gbufferProjection * vec4(currPos, 1.0);
		if(clip.w <= 0.0) break;
		vec3 ndc = clip.xyz / clip.w;
		vec2 uv = ndc.xy * 0.5 + 0.5;

		// Screen bounds / NDC Z check
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || ndc.z < 0.0 || ndc.z > 1.0) break;

		// Sample scene depth (handles DH via getDepthTex)
		float sampledDepth = getDepthTex(uv);
		if(sampledDepth < 1.0){
			// Reconstruct view-space position at this sample
			float mainDepthVal = textureLod(depthtex0, uv, 0).x;
			vec3 hitViewPos;
		#ifdef DISTANT_HORIZONS
			hitViewPos = (mainDepthVal >= 1.0) ? getViewPos(dhProjectionInverse, vec3(uv, sampledDepth)) : getViewPos(gbufferProjectionInverse, vec3(uv, sampledDepth));
		#else
			hitViewPos = getViewPos(gbufferProjectionInverse, vec3(uv, sampledDepth));
		#endif

			// Reject same-surface hits before they can become noisy black reflections.
			float sourceDepth = getDepthTex(screenPos.xy);
			vec3 sourceViewPos = getViewPos(gbufferProjectionInverse, vec3(screenPos.xy, sourceDepth));
			float screenDist = length(uv - screenPos.xy);
			float depthDist = abs(hitViewPos.z - sourceViewPos.z);
			if(screenDist < 0.015 && depthDist < 0.08){
				prevPos = currPos;
				currPos += stepVec * 0.5;
				continue;
			}

			// Positive diff means surface is in front of the marching sample (potential hit)
			float diff = hitViewPos.z - currPos.z;
			// Error tolerance based on current step magnitude and refinement level
			float err = length(stepVec) / pow(2.0, float(refinements));

			if(diff >= 0.0 && diff <= err * 2.0 && refinements < MAX_REFINES){
				// Step back and increase refinement to approach the hit more carefully
				currPos -= stepVec / pow(2.0, float(refinements));
				refinements++;
				continue;
			}

			if(diff >= 0.0 && diff <= err * 4.0 && refinements >= MAX_REFINES){
				// Perform a small binary bisection between prevPos and currPos to refine UV
				vec3 a = prevPos;
				vec3 b = currPos;
				for(int bi = 0; bi < 4; ++bi){
					vec3 m = (a + b) * 0.5;
					vec4 clipM = gbufferProjection * vec4(m, 1.0);
					if(clipM.w <= 0.0){
						a = m;
						continue;
					}
					vec3 ndcM = clipM.xyz / clipM.w;
					vec2 uvM = ndcM.xy * 0.5 + 0.5;
					if(uvM.x < 0.0 || uvM.x > 1.0 || uvM.y < 0.0 || uvM.y > 1.0 || ndcM.z < 0.0 || ndcM.z > 1.0){
						a = m;
						continue;
					}
					float sampledDepthM = getDepthTex(uvM);
					vec3 hitViewPosM;
				#ifdef DISTANT_HORIZONS
					float mainDepthValM = textureLod(depthtex0, uvM, 0).x;
					hitViewPosM = (mainDepthValM >= 1.0) ? getViewPos(dhProjectionInverse, vec3(uvM, sampledDepthM)) : getViewPos(gbufferProjectionInverse, vec3(uvM, sampledDepthM));
				#else
					hitViewPosM = getViewPos(gbufferProjectionInverse, vec3(uvM, sampledDepthM));
				#endif
					if(m.z < hitViewPosM.z && m.z > hitViewPosM.z - 1.0){
						b = m;
					} else {
						a = m;
					}
				}

				// Compute final UV from refined position
				vec4 finalClip = gbufferProjection * vec4(b, 1.0);
				if(finalClip.w <= 0.0) break;
				vec3 finalNdc = finalClip.xyz / finalClip.w;
				vec2 finalUv = finalNdc.xy * 0.5 + 0.5;
				// Reject out-of-range UVs
				if(finalUv.x < 0.0 || finalUv.x > 1.0 || finalUv.y < 0.0 || finalUv.y > 1.0) break;

				// Water/self-surface rejection: reject hits that are effectively the same surface
				// as the current fragment. Otherwise the reflection ray can lock onto the water
				// depth + normal pattern itself, creating black noise and mirrored seams.
				float currentDepth = getDepthTex(screenPos.xy);
				vec3 currentView = getViewPos(gbufferProjectionInverse, vec3(screenPos.xy, currentDepth));
				float hitDepth = getDepthTex(finalUv);
				vec3 hitView = getViewPos(gbufferProjectionInverse, vec3(finalUv, hitDepth));
				float selfScreenRadius = 0.04;
				float selfDepthTolerance = 0.12 + max(0.0, -viewPos.z) * 0.01;
				float screenDelta = length(finalUv - screenPos.xy);
				float depthDelta = abs(hitView.z - currentView.z);
				// Use a combined threshold so nearby same-surface water hits are discarded reliably,
				// while true terrain reflections still survive a slightly larger screen offset.
				if(screenDelta < selfScreenRadius && depthDelta < selfDepthTolerance){
					// Treat as a miss and continue marching with slightly increased refinement
					int nr = refinements + 1;
					refinements = nr > MAX_REFINES ? MAX_REFINES : nr;
					prevPos = currPos;
					currPos += stepVec / pow(2.0, float(refinements));
					continue;
				}
				finalSamplePos = finalUv * vec2(viewWidth, viewHeight);
				break;
			}
		}

		// Advance the ray using the current refinement scale
		prevPos = currPos;
		currPos += stepVec / pow(2.0, float(refinements));

		// Grow step slightly after a couple iterations to cover distance faster
		if(stepsDone > 1) stepVec *= 1.375;

		// Stop if we've marched beyond the far boundary
		if(length(currPos - viewPos) > borderFar) break;

		stepsDone++;
	}

	if(finalSamplePos.x < 0.0 || finalSamplePos.y < 0.0) return vec3(0.0);
	return vec3(finalSamplePos, 1.0);
}

// Signal that the ray tracer implementation has been included
#ifndef RAYTRACER_INCLUDED
#define RAYTRACER_INCLUDED
#endif