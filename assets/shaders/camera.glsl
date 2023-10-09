
/// Returns the color for the sky dome.
vec4 SkyDome(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.5 * (rayDir.y + 1.2);
    return mix(vec4(0.8, 0.8, 0.8, 1.0), vec4(0.141, 0.227, 0.388, 1.0), t);
}