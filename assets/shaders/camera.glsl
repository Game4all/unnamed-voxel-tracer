
layout (binding = 8) uniform u_Camera {
    vec4 C_position;
    mat4 C_view;
    float fov;
};

const vec3 SUN_DIR = vec3(7.52185881e-01, 6.58950984e-01, 7.52185881e-01);

// extracted from https://www.shadertoy.com/view/XslGRr
vec4 SkyDome2(in vec3 ro, in vec3 rd)
{
    float sun = clamp(dot(normalize(SUN_DIR), normalize(rd)), 0.0, 1.2 );    
    vec3 col = vec3(0.6, 0.71, 0.75) - rd.y * 0.2 * vec3(1.0, 0.5, 1.0) + 0.15 * 0.5;    
    col += 0.4 * vec3(1.0, .6, 0.1) * pow(sun, 8.0);             
    // sun glare        
    col += vec3(0.2, 0.08, 0.04) * pow(sun, 3.0);    
    return vec4(col, 1.0);
}

