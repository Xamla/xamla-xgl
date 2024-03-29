#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texCoords;
layout (location = 2) in vec3 colorIn;
//layout (location = 1) in vec3 normal;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vertexColor;
//out vec2 TexCoords;


void main()
{
    gl_Position = projection * view * model * vec4(position, 1.0f);
    vertexColor = colorIn;
    //TexCoords = vec2(texCoords.x, 1.0 - texCoords.y);
}

