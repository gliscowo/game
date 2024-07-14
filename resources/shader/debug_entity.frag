#version 330 core

uniform vec4 uSurfaceColor;

out vec4 fragColor;

void main() {
    fragColor = uSurfaceColor;
}