#version 450

layout(binding = 0) uniform sampler2D tex;

layout(location = 0) in vec2 texPosition;

out vec4 fragColor;

void main() {
    fragColor = texture(tex, texPosition);
}