//rt api selector

#define RT_API 2 //[1 2 3]
#define STUPID_RT_BIAS_IRIS_BUG 0.0 //[0.0 1.0 2.0 3.0]
#define RT_STEPS 100 //[30 40 50 100 150 200]

#if RT_API == 1
    #include "/stuff/rt/rt1.glsl"
#endif

#if RT_API == 2
    #include "/stuff/rt/rt2.glsl"
#endif

#if RT_API == 3
    #include "/stuff/rt/rt3.glsl"
#endif
