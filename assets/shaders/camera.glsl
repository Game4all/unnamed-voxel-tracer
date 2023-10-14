
/// Returns the color for the sky dome.
vec4 SkyDome(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.5 * (rayDir.y + 1.2);
    return mix(vec4(0.8, 0.8, 0.8, 1.0), vec4(0.141, 0.227, 0.388, 1.0), t);
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