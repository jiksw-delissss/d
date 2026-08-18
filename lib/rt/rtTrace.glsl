/*
    DDA voxel raytracer.
    Ported from timetravelbeard's Voxelizing Tutorial (stuff/rt/rt2.glsl) into SDV's naming
    conventions. Marches a ray through cimage1 one voxel at a time using a DDA step, so it
    never skips a voxel regardless of ray angle.

    Requires (declared by the including file):
        layout(r32ui) uniform uimage3D cimage1;
        VOXEL_AREA, RT_STEPS  (from /lib/settings.glsl)
*/

#if defined(RAYTRACING_DEBUG_VIEW) || defined(VOXEL_RT_REFLECTIONS)

#define RT_TRACE_BIAS 0.001

struct TracedRay {
    vec3 pos;
    bool hitSomething;
    vec3 normalFace;
    vec3 dir;
    vec4 albedo;
};

#ifdef VOXEL_REJECT_ISOLATED_HITS
// Same neighbor-occupancy idea as timetravelbeard's "thick vs thin grass" check
// (Voxelizing Tutorial ep.13): there, an isolated grass-colored voxel with no
// grass-colored horizontal neighbors got colored red as a "this is broken" debug
// signal. Here we use the same 4-neighbor test generically (any occupancy, not just
// grass color) and act on it directly: a hit with no horizontal neighbor at all is
// almost certainly a stray single-point write from thin/cross-shaped geometry that
// slipped past the normal-axis rejection in voxelizeWrite.glsl, so treat it as if the
// ray passed through empty space instead of stopping there.
bool sdv_isIsolatedVoxel(in ivec3 voxelPos){
    ivec3 area = ivec3(VOXEL_AREA - 1);
    ivec3 px = voxelPos + ivec3(1,0,0), nx = voxelPos - ivec3(1,0,0);
    ivec3 pz = voxelPos + ivec3(0,0,1), nz = voxelPos - ivec3(0,0,1);
    bool hasNeighbor =
        (clamp(px, ivec3(0), area) == px && imageLoad(cimage1, px).r != 0u) ||
        (clamp(nx, ivec3(0), area) == nx && imageLoad(cimage1, nx).r != 0u) ||
        (clamp(pz, ivec3(0), area) == pz && imageLoad(cimage1, pz).r != 0u) ||
        (clamp(nz, ivec3(0), area) == nz && imageLoad(cimage1, nz).r != 0u);
    return !hasNeighbor;
}
#endif

// Ported from the RT tutorial's DDA voxel tracer: march one voxel at a time,
// never skipping the cell the ray crosses, and stop on the first occupied voxel.
TracedRay sdv_traceRay(in vec3 pos, in vec3 dir){
    TracedRay ray;
    ray.hitSomething = false;
    ray.albedo = vec4(0.0);
    ray.normalFace = vec3(0.0);
    ray.dir = dir;
    ray.pos = pos;

    if(length(dir) < 1e-5) return ray;

    vec3 travelDir = normalize(dir);

    // convert from player space to voxel space. Scale by VOXEL_SUBDIV first so we're
    // marching in the same sub-block-sized cells that voxelizeWrite.glsl writes into --
    // direction stays unit length so the DDA step math below is unaffected by the scale.
    pos = pos * float(VOXEL_SUBDIV) + fract(cameraPosition) * float(VOXEL_SUBDIV) + float(VOXEL_AREA) * 0.5;

    for(int steps = 0; steps < RT_STEPS && !ray.hitSomething; steps++){
        // distance to each next voxel boundary along the current direction
        vec3 stepDir = sign(travelDir);
        vec3 edgeDist = vec3(
            stepDir.x > 0.0 ? 1.0 - fract(pos.x) : fract(pos.x),
            stepDir.y > 0.0 ? 1.0 - fract(pos.y) : fract(pos.y),
            stepDir.z > 0.0 ? 1.0 - fract(pos.z) : fract(pos.z)
        );
        edgeDist += 1.0 - abs(sign(edgeDist));
        edgeDist /= max(vec3(0.001), abs(travelDir));
        float advance = min(min(edgeDist.x, edgeDist.y), edgeDist.z) + RT_TRACE_BIAS;

        ivec3 lastVoxel = ivec3(pos);
        pos += advance * travelDir;

        ivec3 voxelPos = ivec3(pos);
        if(clamp(voxelPos, ivec3(0), ivec3(VOXEL_AREA - 1)) == voxelPos){
            uint packedVoxel = imageLoad(cimage1, voxelPos).r;
            if(packedVoxel != 0u
                #ifdef VOXEL_REJECT_ISOLATED_HITS
                    && !sdv_isIsolatedVoxel(voxelPos)
                #endif
            ){
                // Use the hit cell's own color directly. The old version averaged in the
                // 26 surrounding cells regardless of what they belonged to, which blurred
                // silhouettes together (e.g. bleeding terrain color into an entity right
                // next to it) instead of resolving shape -- the actual fix for blocky,
                // shapeless reflections is the higher VOXEL_SUBDIV grid resolution above.
                ray.hitSomething = true;
                ray.albedo = unpackUnorm4x8(packedVoxel);
                ray.normalFace = vec3(lastVoxel - voxelPos);
            }
        }
    }

    // back to player space (reverse of the forward transform above)
    pos = (pos - float(VOXEL_AREA) * 0.5) / float(VOXEL_SUBDIV) - fract(cameraPosition);
    ray.pos = pos;
    ray.dir = travelDir;
    return ray;
}

float sdv_traceShadow(in vec3 origin, in vec3 lightDir){
    vec3 pos = origin * float(VOXEL_SUBDIV) + fract(cameraPosition) * float(VOXEL_SUBDIV) + float(VOXEL_AREA) * 0.5;
    vec3 dir = normalize(lightDir);

    for(int steps = 0; steps < RT_STEPS; steps++){
        vec3 stepDir = sign(dir);
        vec3 edgeDist = vec3(
            stepDir.x > 0.0 ? 1.0 - fract(pos.x) : fract(pos.x),
            stepDir.y > 0.0 ? 1.0 - fract(pos.y) : fract(pos.y),
            stepDir.z > 0.0 ? 1.0 - fract(pos.z) : fract(pos.z)
        );
        edgeDist += 1.0 - abs(sign(edgeDist));
        edgeDist /= max(vec3(0.001), abs(dir));
        float advance = min(min(edgeDist.x, edgeDist.y), edgeDist.z) + RT_TRACE_BIAS;

        pos += dir * advance;

        ivec3 voxelPos = ivec3(pos);
        if(clamp(voxelPos, ivec3(0), ivec3(VOXEL_AREA - 1)) == voxelPos){
            uint packedVoxel = imageLoad(cimage1, voxelPos).r;
            if(packedVoxel != 0u) return 0.0;
        }
    }

    return 1.0;
}

// RT-based reflection tracer: uses the same DDA voxel traversal as the tutorial.
TracedRay sdv_traceReflection(in vec3 pos, in vec3 reflectDir){
    return sdv_traceRay(pos, reflectDir);
}

#endif
