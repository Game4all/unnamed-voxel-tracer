
/// Returns the color for the sky dome.
vec4 SkyDome(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.5 * (rayDir.y + 1.2);
    return mix(vec4(0.8, 0.8, 0.8, 1.0), vec4(0.141, 0.227, 0.388, 1.0), t);
}

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

vec3 Reinhardt(vec3 color)
{
    const float gamma = 2.2;
	float white = 2.;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float toneMappedLuma = luma * (1. + luma / (white*white)) / (1. + luma);
	color *= toneMappedLuma / luma;
	color = pow(color, vec3(1. / gamma));
	return color;
}

vec3 UE3_Tonemapper(vec3 x) {
	return x / (x + 0.187) * 1.035;
}