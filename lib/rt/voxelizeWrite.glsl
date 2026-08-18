/*
    Writes a coarse world-space representation of terrain into cimage1 during the shadow
    pass, so the raytracer (rtTrace.glsl) has something to march through.

    Two write paths, adapted from timetravelbeard's Voxelizing Tutorial (voxelizing.glsl):
      - sdv_writeVoxelFace(): axis-aligned solid faces (full-cube blocks) fill every
        subcell across the face. Returns false and writes nothing for non-axis-aligned
        geometry -- see below.
      - sdv_writeVoxel(): single-point corner write, nudged inward along the vertex
        normal. This is the fallback for non-blocky shapes (cross-shaped plants, leaves
        edges, anything sdv_writeVoxelFace rejects) -- called from shadow_cutout.glsl /
        shadow_block.glsl when sdv_writeVoxelFace returns false, so these still show up
        in reflections as a rough single-cell proxy instead of not voxelizing at all.

    Requires (declared by the including file):
        layout(r32ui) uniform uimage3D cimage1;
        uniform sampler2D gtexture;
        uniform vec3 cameraPosition;
        uniform mat4 shadowModelViewInverse;
        attribute vec3 at_midBlock;
        VOXEL_AREA, VOXEL_SUBDIV (from /lib/settings.glsl)
*/

#if defined(RAYTRACING_DEBUG_VIEW) || defined(VOXEL_RT_REFLECTIONS)

void sdv_storeVoxel(in ivec3 voxelPos, in vec4 voxelData){
    if(clamp(voxelPos, ivec3(0), ivec3(VOXEL_AREA - 1)) != voxelPos) return;

    uint oldPacked = imageLoad(cimage1, voxelPos).r;
    if(oldPacked == 0u){
        imageStore(cimage1, voxelPos, uvec4(packUnorm4x8(voxelData), 0u, 0u, 0u));
        return;
    }

    vec4 oldColor = unpackUnorm4x8(oldPacked);
    vec3 mergedColor = mix(oldColor.rgb, voxelData.rgb, 0.5);
    imageStore(cimage1, voxelPos, uvec4(packUnorm4x8(vec4(mergedColor, 1.0)), 0u, 0u, 0u));
}

void sdv_writeVoxel(in vec3 shadowViewPos, in vec2 texCoord, in vec3 vertColor){
    vec3 footPos = (shadowModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;
    // 0.015625 = 1/64, matches SDV's existing at_midBlock scale. Scale by VOXEL_SUBDIV
    // so a "voxel" is 1/VOXEL_SUBDIV of a block instead of a whole block.
    vec3 vertPos = footPos + at_midBlock * 0.015625 + fract(cameraPosition);

    vec4 texSample = textureLod(gtexture, texCoord, log2(float(textureSize(gtexture, 0).x)));
    if(texSample.a < ALPHA_THRESHOLD) return;
    vec4 voxelData = vec4(texSample.rgb * vertColor, 1.0);

    // Nudge inward along the face normal before quantizing. Without this, a vertex that
    // sits exactly on a cell boundary (local position 0.0 or 1.0) floors inconsistently
    // between this block's cell and the neighbor's depending on float rounding -- across
    // thousands of adjacent terrain quads that shows up as a checkerboard of holes.
    // Pulling every vertex slightly toward the solid side of the surface first makes the
    // floor land on the same cell every time.
    vec3 nudged = vertPos - normalize(gl_Normal) * 0.001;
    ivec3 baseVoxel = ivec3(nudged * float(VOXEL_SUBDIV) + float(VOXEL_AREA) * 0.5);

    // Write from every vertex of the quad, not just vertex 0, so a face's corners span
    // the cells they should instead of collapsing to one.
    sdv_storeVoxel(baseVoxel, voxelData);
}

// Full-cube terrain (shadow_solid.glsl) only: a solid block's face is planar and spans
// the whole block edge-to-edge in the two axes tangent to its normal, so instead of
// relying on 4 corner samples (which leave the interior of the face empty once
// VOXEL_SUBDIV > 2), fill every subcell across the face directly.
//
// NOTE: gl_Normal's Iris docs only list it as valid in gbuffers_*.vsh and shadow.vsh --
// NOT the split shadow_solid/shadow_block/shadow_cutout/shadow_entities programs added
// in Iris 1.8. It may or may not actually be populated there depending on Iris version.
// If it comes through as zero/garbage here, that corrupts the whole face fill (wrong
// axis picked -> writes land outside the real face), which reads as broken/disjointed
// terrain shape. So: bail out to the safe single-point corner write whenever the normal
// doesn't look like a valid unit vector, rather than trusting it blindly.
//
// Returns true if it did a full-face fill, false if it rejected the geometry (bad normal,
// non-axis-aligned, or below the alpha threshold) -- callers use that to fall back to
// sdv_writeVoxel() for non-blocky shapes instead of just dropping them.
bool sdv_writeVoxelFace(in vec3 shadowViewPos, in vec2 texCoord, in vec3 vertColor){
    vec3 footPos = (shadowModelViewInverse * vec4(shadowViewPos, 1.0)).xyz;
    vec3 vertPos = footPos + at_midBlock * 0.015625 + fract(cameraPosition);

    vec4 texSample = textureLod(gtexture, texCoord, log2(float(textureSize(gtexture, 0).x)));
    if(texSample.a < ALPHA_THRESHOLD) return false;
    vec4 voxelData = vec4(texSample.rgb * vertColor, 1.0);

    float normalLen = length(gl_Normal);
    if(normalLen < 0.5 || normalLen > 2.0){
        // gl_Normal isn't trustworthy here -- reject the write instead of letting a
        // non-blocky surface leak into the coarse RT volume.
        return false;
    }

    vec3 n = gl_Normal / normalLen;
    vec3 absN = abs(n);
    if(max(absN.x, max(absN.y, absN.z)) < 0.8){
        // Not a true axis-aligned solid face -- non-blocky shape, let the caller fall
        // back to the corner-write instead.
        return false;
    }
    // Step just inside the solid block so floor() lands on the block behind the face,
    // not the empty one in front of it.
    ivec3 blockOrigin = ivec3(floor(vertPos - n * 0.001));

    for(int i = 0; i < VOXEL_SUBDIV; i++){
        for(int j = 0; j < VOXEL_SUBDIV; j++){
            vec3 cellLocal;
            float tA = (float(i) + 0.5) / float(VOXEL_SUBDIV);
            float tB = (float(j) + 0.5) / float(VOXEL_SUBDIV);
            // 0.001 / 0.999 inset instead of an exact 0/1 boundary -- same reasoning as
            // the nudge above, keeps this face's own cell out of boundary ambiguity.
            if(absN.x > 0.5)      cellLocal = vec3(n.x > 0.0 ? 0.999 : 0.001, tA, tB);
            else if(absN.y > 0.5) cellLocal = vec3(tA, n.y > 0.0 ? 0.999 : 0.001, tB);
            else                   cellLocal = vec3(tA, tB, n.z > 0.0 ? 0.999 : 0.001);

            vec3 samplePos = (vec3(blockOrigin) + cellLocal) * float(VOXEL_SUBDIV);
            ivec3 voxelPos = ivec3(samplePos + float(VOXEL_AREA) * 0.5);
            sdv_storeVoxel(voxelPos, voxelData);
        }
    }
    return true;
}

#endif
