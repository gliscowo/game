#version 330 core

uniform mat4 uProjection;
uniform mat4 uView;
uniform float uScale;
uniform vec3 uPos;

in vec3 aPos;

void main() {
    gl_Position = uProjection * uView * vec4((aPos * uScale) + uPos, 1.0);
}