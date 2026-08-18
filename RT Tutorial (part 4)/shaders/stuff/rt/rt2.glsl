// MIT License: Do Whatever you want to with this code as long as this line stays in the file. This file contains code Copyright © 2026 timetravelbeard (contact: https://www.patreon.com/timetravelbeard , https://youtube.com/@timetravelbeard3588 , https://discord.gg/S6F4r6K5yU )  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#if RT_API == 2

//DDA Trace



// Settings

    #define V_TRACE_BIAS 0.001



// Data Structures

struct Traced_ray{
    vec3 pos;
    bool hit_something;
    vec3 normals_face;
    vec3 dir;
    vec2 uvs;

//temp
    vec4 albedo;
};



// Functions

Traced_ray trace_ray(in vec3 pos, in vec3 dir)
{
    //initiate
    Traced_ray this_ray;
    this_ray.hit_something = false;
    
    //convert to voxel space
    pos+=VOXEL_AREA/2+fract(cameraPosition);
    
    //trace ray
    for(int steps = 0; steps < RT_STEPS && !this_ray.hit_something ; steps ++)
    {
        
         //calculate dda
            vec3 a;
            {
	            vec3 d= sign(dir);
	            a = //get the distance to the edge in all 3 directions
			        vec3(
			             (sign(d.x)>0. ?
                       	    1.-fract(pos.x)
                       		: fract(pos.x)
			             )
			            ,
			             (sign(d.y)>0. ?
                       	    1.-fract(pos.y)
                       		: fract(pos.y)
			             )
			            ,
			             (sign(d.z)>0. ?
                       	    1.-fract(pos.z)
                       		: fract(pos.z)
			             )
			            );
                 a+=1-abs(sign(a)); //fix cracks when it is 0 distance to an edge by ignoring that direction
			     a/=max(vec3(0.001),abs(dir)); //how many steps to reach each edge at current velocity
			     a.x= min( min(a.x,a.y),a.z)+V_TRACE_BIAS;//take the smallest amount of steps to an edge, plus a bias to go into it
             }

        //save last position to tell which side of a block we are going to hit
            ivec3 last_pos = ivec3(pos);

        //increment ray by DDA amount
		    pos+= a.x*dir.xyz;
        

        //check for hit
        ivec3 voxel_pos = ivec3(pos);
        if( clamp(voxel_pos,0,VOXEL_AREA) == voxel_pos )
	    { //if inside Voxel Area
		    //get data, unpack, visualize
            uint integerValue = imageLoad(cimage1,voxel_pos ).r;
            
            this_ray.hit_something = integerValue != 0u;
            if(this_ray.hit_something)
            {
			    this_ray.albedo = unpackUnorm4x8( imageLoad(cimage1,voxel_pos ).r );
                this_ray.normals_face = vec3(last_pos-voxel_pos);
            }
            
        }
    }
    
    ///debug
    
    //return to player_space
    pos-=VOXEL_AREA/2+fract(cameraPosition);

    //output result
    this_ray.pos = pos;
    this_ray.dir = dir;
    return this_ray;
}
#endif
