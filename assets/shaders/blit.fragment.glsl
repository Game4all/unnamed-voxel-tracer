#version 450

#include assets/shaders/camera.glsl

layout(binding = 0) uniform sampler2D frameColor;
layout(binding = 1) uniform sampler2D frameNormal;
layout(binding = 2) uniform sampler2D framePosition;
layout(binding = 3) uniform sampler2D frameIllumination;

layout (binding = 8) uniform u_Camera {
    vec4 C_position;
    mat4 C_view;
    vec4 C_sun_dir;
    float fov;
    uint frameIndex;
    uint frameAccum;
};

layout(location = 0) in vec2 texPos;

out vec4 fragColor;

const float vignette_intensity = 0.6;
const float vignette_opacity = 0.3;

float vignetteEffect(vec2 uv) {
	uv *= 1.0 - uv.xy;
	return pow(uv.x * uv.y * 15.0, vignette_intensity * vignette_opacity);
}

vec4 gaussianBlur(in vec2 uv) {
    ivec2 pixelCoords = ivec2(uv * textureSize(frameIllumination, 0));

    const int SEARCH_LEN = 1;
    vec4 sum = vec4(0); 
    vec3 normal = vec3(0);
    for (int i = -SEARCH_LEN; i <= SEARCH_LEN; i++) {
        for (int j = -SEARCH_LEN; j <= SEARCH_LEN; j++) {
            sum += texelFetch(frameIllumination, pixelCoords + ivec2(i, j), 0);
            normal += texelFetch(frameNormal, pixelCoords + ivec2(i, j), 0).xyz;

            if (length(normal) > 5.)
                return texelFetch(frameIllumination, pixelCoords, 0);
        }
    }
    sum /= pow((2 * SEARCH_LEN + 1), 2);

    return sum;
}
 
void main() {
    vec2 rayUV = texPos * 2.0 - 1.0;

    vec3 rayPos = texture(framePosition, texPos).xyz;
    vec4 illumination = texture(frameIllumination, texPos);

    vec4 color = texture(frameColor, texPos);
    color += illumination.a * SkyDome2(rayPos, illumination.xyz, normalize(C_sun_dir.xyz));

    color = length(texPos - vec2(0.5)) <= 0.002 ? mix(color, vec4(1.0, 1.0, 1.0, 0.4), 0.5) : color;
    float grad = vignetteEffect(texPos);
    fragColor = grad * color;
}

