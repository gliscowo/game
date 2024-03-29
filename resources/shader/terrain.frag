#version 330 core

uniform sampler2D uTexture;

in vec3 vNormal;
in vec2 vUv;

out vec4 fragColor;

void main() {
    fragColor = texture(uTexture, vUv);
}