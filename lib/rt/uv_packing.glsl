/*
    UV packing/unpack functions for voxel texturing in RT.
    Ported from timetravelbeard's RT Tutorial Part 4 (stuff/uv_packing.glsl).

    When TEXTURES_IN_RT > 0, per-voxel texture atlas UVs and glcolor are packed
    into uint32 and stored in a second 3D image (c_image4_voxel_scene). During
    RT tracing these are unpacked to reconstruct actual texture atlas samples.

    Requires (declared by the including file):
        uniform sampler2D atlas_a;        // minecraft:block atlas
        layout(r32ui) uniform uimage3D c_image4_voxel_scene;
*/

#if TEXTURES_IN_RT > 0

// Pack atlas UV coordinates + texture tile size into a uint32.
//   uvst.xy = normalized UV of the quad's origin in the atlas (0-1)
//   uvst.zw = size of the quad in atlas UV space
//   normals_face = face normal (used to select which axis to map during tracing)
//
// Bit layout:
//   bits  0-2  (3 bits)  : facing direction (priority hint, not strictly needed for SDV)
//   bits  3-5  (3 bits)  : texture tile size category (8..1024)
//   bits  6-18 (13 bits) : U coordinate (0-8191 range)
//   bits 19-31 (13 bits) : V coordinate (0-8191 range)
uint sdv_packUVBuffer(in vec4 uvst, in vec3 normalsFace)
{
    // Facing priority (unused by SDV tracer but preserved for compatibility)
    vec3 cameraDir = vec3(1.0, 0.0, 0.0);
    uint facing = uint(4.0 + 4.0 * dot(normalsFace, -cameraDir));

    // Texture tile size: determine which power-of-two bucket the quad falls into
    ivec2 atlasWH = ivec2(textureSize(atlas_a, 0));
    uvst.ba *= atlasWH;

    uint texST =
        uvst.b > 1020.0 ? 7u :
        uvst.b > 511.0  ? 6u :
        uvst.b > 255.0  ? 5u :
        uvst.b > 127.0  ? 4u :
        uvst.b > 63.0   ? 3u :
        uvst.b > 31.0   ? 2u :
        uvst.b > 15.0   ? 1u :
        0u;

    // UV coordinates scaled to 13-bit range (0-8191)
    ivec2 uv = ivec2(8191.0 * uvst.xy);

    // Pack into uint32
    uint integerValue = bitfieldInsert(0u, facing, 0, 3);
    integerValue = bitfieldInsert(integerValue, texST, 3, 3);
    integerValue = bitfieldInsert(integerValue, uv.x, 6, 13);
    integerValue = bitfieldInsert(integerValue, uv.y, 19, 13);

    return integerValue;
}

// Unpack a uint32 back into atlas UV origin + tile size.
// Returns vec4( u, v, tileWidth, tileHeight ) in atlas UV space.
vec4 sdv_unpackUVBuffer(in uint integerValue)
{
    vec4 uvst;

    // Extract UVs
    uvst.x = float(bitfieldExtract(integerValue, 6, 13)) / 8191.0;
    uvst.y = float(bitfieldExtract(integerValue, 19, 13)) / 8191.0;

    // Extract texture tile size and convert to atlas UV scale
    uint texST = bitfieldExtract(integerValue, 3, 3);
    vec2 iAtlasWH = 1.0 / vec2(textureSize(atlas_a, 0));

    uvst.ba =
        texST == 7u ? 1024.0 * iAtlasWH :
        texST == 6u ? 512.0  * iAtlasWH :
        texST == 5u ? 256.0  * iAtlasWH :
        texST == 4u ? 128.0  * iAtlasWH :
        texST == 3u ? 64.0   * iAtlasWH :
        texST == 2u ? 32.0   * iAtlasWH :
        texST == 1u ? 16.0   * iAtlasWH :
        8.0 * iAtlasWH;

    return uvst;
}

// Pack a vec3 color (0-1) into 12 bits (4 bits per channel) using bitwise ops.
// Inverted before packing so imageAtomicMax (which selects the largest value)
// effectively selects the darkest/most-recent write.
uint sdv_packColorChannel3(in vec3 v)
{
    v = clamp(1.0 - v, 0.0, 1.0);
    uvec3 rgbu = uvec3(v * 15.9);
    return rgbu.r | (rgbu.g << 4) | (rgbu.b << 8);
}

// Unpack 12-bit packed color back to vec3 (0-1).
vec3 sdv_unpackColorChannel3(in uint v)
{
    return clamp(1.0 - vec3(
        float(v & 0xFu),
        float((v >> 4) & 0xFu),
        float((v >> 8) & 0xFu)
    ) / 15.0, 0.0, 1.0);
}

#endif // TEXTURES_IN_RT > 0
