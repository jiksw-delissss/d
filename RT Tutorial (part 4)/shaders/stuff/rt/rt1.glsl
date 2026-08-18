#if RT_API == 1

//settings
    #define RT_NIAVE_STEP_SIZE 0.5 //[0.1 0.2 0.5 1.0 2.0]


//atructures
    struct Traced_ray{
        vec3 pos;
        bool hit_something;
        vec3 normals_face;
        vec3 dir;
        vec2 uvs;

    //temp
        vec4 albedo;
    };


//functions

    Traced_ray trace_ray(in vec3 pos, in vec3 dir)
    {
        //initiate
        Traced_ray this_ray;
        this_ray.hit_something = false;
        
        //trace ray
        for(int steps = 0; steps < RT_STEPS && !this_ray.hit_something ; steps ++)
        {
            //step ray forward
            pos+=dir*RT_NIAVE_STEP_SIZE;

            //check for hit
            ivec3 voxel_pos = ivec3(pos+VOXEL_AREA/2+fract(cameraPosition));//convert from player space to voxel space
            if( clamp(voxel_pos,0,VOXEL_AREA) == voxel_pos ) 
	        { //if inside Voxel Area
		        //get data, unpack, visualize
                uint integerValue = imageLoad(cimage1,voxel_pos ).r;
                
                this_ray.hit_something = integerValue != 0u;
			    this_ray.albedo = unpackUnorm4x8( imageLoad(cimage1,voxel_pos ).r );
                
            }
        }
        
        ///debug


        //output result
        this_ray.pos = pos;
        this_ray.dir = dir;
        return this_ray;
    }


#endif
//> RT_API == 1
