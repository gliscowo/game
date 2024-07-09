#version 330 core

uniform sampler2D uTexture;
uniform sampler2D uSky;
uniform vec2 uSkySize;

uniform vec4 uFogColor;
uniform float uFogStart;
uniform float uFogEnd;

in vec3 vNormal;
in vec2 vUv;
in float vDistance;

out vec4 fragColor;

void main() {
    float lightingStrength = min(1, abs(vNormal.y) + abs(vNormal.x * .85) + abs(vNormal.z * .65));

    vec4 surfaceColor = texture(uTexture, vUv);
    vec4 color = vec4(surfaceColor.rgb * lightingStrength, surfaceColor.a);

    fragColor = mix(color, texture(uSky, gl_FragCoord.xy / uSkySize), smoothstep(uFogStart, uFogEnd, vDistance));
}