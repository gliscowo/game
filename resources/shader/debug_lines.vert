#version 330 core

uniform mat4 uProjection;
uniform mat4 uView;

in vec3 aPos;
in vec4 aColor;

out vec4 vColor;

void main() {
    vColor = aColor;
    gl_Position = uProjection * uView * vec4(aPos, 1.0);
}