#version 450

#include assets/shaders/camera.glsl

layout(binding = 0) uniform sampler2D frameColor;
layout(binding = 1) uniform sampler2D frameNormal;
layout(binding = 2) uniform sampler2D framePosition;
layout(binding = 3) uniform sampler2D frameIllumination;


layout(location = 0) in vec2 texPos;

out vec4 fragColor;

const float vignette_intensity = 0.6;
const float vignette_opacity = 0.3;

float vignetteEffect(vec2 uv) {
	uv *= 1.0 - uv.xy;
	return pow(uv.x * uv.y * 15.0, vignette_intensity * vignette_opacity);
}
 
void main() {
    vec2 rayUV = texPos * 2.0 - 1.0;

    vec3 rayPos = texture(framePosition, texPos).xyz;
    vec3 normal = texture(frameNormal, texPos).xyz;
    vec4 illumination = texture(frameIllumination, texPos);

    vec4 color = texture(frameColor, texPos);
    color += illumination.a * SkyDome2(rayPos + normal * 0.001, illumination.xyz);

    color = length(texPos - vec2(0.5)) <= 0.002 ? mix(color, vec4(1.0, 1.0, 1.0, 0.4), 0.5) : color;
    float grad = vignetteEffect(texPos);
    fragColor = grad * color;
}

