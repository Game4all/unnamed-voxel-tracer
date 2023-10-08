

/// Rotate the ray vector by the given angle around the X axis (pitch).
mat3 CamRotateX(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat3(
        1.0, 0.0, 0.0,
        0.0, c, s,
        0.0, -s, c
    );
}

/// Rotate the ray vector by the given angle around the Y axis (yaw).
mat3 CamRotateY(float theta) {
    float c = cos(theta);
    float s = -sin(theta);
    return mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );
}


/// Returns a ray from the camera settings.
vec3 CameraRay(vec3 rayOrigin, vec3 rayDirection, vec2 pitch_yaw) {
    vec3 rayDir = CamRotateY(pitch_yaw.y) * CamRotateX(pitch_yaw.x) * rayDirection;
    return rayDir;
}

/// Returns the color for the sky dome.
vec4 SkyDome(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.5 * (rayDir.y + 1.2);
    return mix(vec4(0.8, 0.8, 0.8, 1.0), vec4(0.141, 0.227, 0.388, 1.0), t);
}