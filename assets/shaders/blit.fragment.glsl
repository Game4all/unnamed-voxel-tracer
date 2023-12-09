#version 450

#include assets/shaders/camera.glsl

layout(binding = 0) uniform sampler2D frameColor;
layout(binding = 1) uniform sampler2D frameNormals;
layout(binding = 2) uniform sampler2D framePositions;

layout(location = 0) in vec2 texPos;

out vec4 fragColor;

const float vignette_intensity = 0.6;
const float vignette_opacity = 0.3;

float vignetteEffect(vec2 uv) {
	uv *= 1.0 - uv.xy;
	return pow(uv.x * uv.y * 15.0, vignette_intensity * vignette_opacity);
}

void main() {
    vec2 textureDelta = vec2(1.0, 1.0) / vec2(textureSize(frameColor, 0));
    vec4 color = vec4(UE3_Tonemapper(texture(frameColor, texPos).xyz), 1.0);
    
    float grad = vignetteEffect(texPos);
    fragColor = grad * color;
}