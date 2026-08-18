//Voxelizing    
    #define VISUALIZED_DATA 5 //[0 1 2 3 4 5]
    #define VOXEL_AREA 128 //[32 64 128]

    //set the voxelizing distance that isn't culled off-screen
    #if VOXEL_AREA == 32
        const float voxelDistance = 32.0;
    #endif
    #if VOXEL_AREA == 64
        const float voxelDistance = 64.0;
    #endif
    #if VOXEL_AREA == 128
        const float voxelDistance = 128.0;
    #endif

//RT
    #define RAYTRACING_VIEW 1 //[0 1]
    #define VOXELIZED_DEBUG_VIEW 0 //[0 1]
    #define RT_SHADOWS_IN_RT_DEBUG_VIEW 0 //[0 1]
    #define SOFT_RT_SHADOWS 0 //[0 1]
    #define RT_SHADOWS_IN_GBUFFERS 0 //[0 1]
    #define SUN_WIDTH 8.0 //[0.001 0.002 0.003 0.004 0.005 0.007 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.2 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

    #define USE_TEXTURE_NORMALS 1 //[0 1]
    //Textures in RT
	#define TEXTURES_IN_RT 2 //[0 2 3 5]
	#define IRON_MIRRORS 0 //[0 1]


