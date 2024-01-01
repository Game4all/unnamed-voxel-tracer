#version 450

#include assets/shaders/camera.glsl

layout(binding = 0) uniform sampler2D frameColor;
layout(binding = 1) uniform sampler2D frameNormal;

layout(location = 0) in vec2 texPos;

out vec4 fragColor;

const float vignette_intensity = 0.6;
const float vignette_opacity = 0.3;

float vignetteEffect(vec2 uv) {
	uv *= 1.0 - uv.xy;
	return pow(uv.x * uv.y * 15.0, vignette_intensity * vignette_opacity);
}

void main() {
    vec4 color = texture(frameColor, texPos);
    color = length(texPos - vec2(0.5)) <= 0.002 ? mix(color, vec4(1.0, 1.0, 1.0, 0.4), 0.5) : color;

    float grad = vignetteEffect(texPos);
    fragColor = grad * color;
}

