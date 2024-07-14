#version 450 core

struct InstanceData {
    vec4 color;
    vec3 pos;
    float scale;
};

layout(binding = 0) readonly buffer ssbo {
    InstanceData[] instances;
};

uniform mat4 uProjection;
uniform mat4 uView;

in vec3 aPos;

out vec4 vColor;

void main() {
    InstanceData instance = instances[gl_InstanceID];

    vColor = instance.color;
    gl_Position = uProjection * uView * vec4((aPos * instance.scale) + instance.pos, 1.0);
}