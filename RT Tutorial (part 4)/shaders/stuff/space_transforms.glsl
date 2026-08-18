//space transforms

vec3 project_and_divide( in mat4 m, in vec3 pos ) {
    vec4 homogenous = m * vec4(pos,1.);
    return homogenous.xyz / homogenous.w;
}

vec3 screen_to_view_space(in vec3 screen_pos) {
    return project_and_divide(gbufferProjectionInverse, screen_pos *2. - 1.);
}

vec3 view_to_foot_space(vec3 pos) {
    return  ( gbufferModelViewInverse * vec4(pos ,1.) ).xyz;
}
