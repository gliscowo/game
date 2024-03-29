#version 330 core

uniform mat4 uProjection;
uniform mat4 uView;
uniform vec3 uOffset;

in vec3 aPos;
in vec3 aNormal;
in vec2 aUv;

out vec3 vNormal;
out vec2 vUv;

void main() {
    gl_Position = uProjection * uView * vec4(aPos.xyz + uOffset, 1.0);
    vNormal = aNormal;
    vUv = aUv;
}