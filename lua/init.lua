local xgl = require 'xgl.env'

require 'xgl.Camera'
require 'xgl.Shader'
require 'xgl.Model'
require 'xgl.SimpleScene'
require 'xgl.Material'
require 'xgl.Mesh'
require 'xgl.geo'

local default_shader
local default_material

local default_depth_shader
local default_depth_material


local DEFAULT_VERTEX_SHADER = [[
#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoords;
layout (location = 3) in vec4 colorIn;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec2 TexCoords;
out vec3 FragPos;
out vec3 Normal;
out vec4 VertexColor;

void main() {
  gl_Position = projection * view * model * vec4(position, 1.0f);
  TexCoords = texCoords;
  FragPos = vec3(model * vec4(position, 1.0f));
  Normal = mat3(transpose(inverse(model))) * normal;
  VertexColor = colorIn;
}
]]

local DEFAULT_FRAGMENT_SHADER = [[
#version 330 core

struct Material {
  vec3 ambient;
  vec3 diffuse;
  vec3 specular;
  float shininess;
  float opacity;
};

uniform Material material;

uniform vec3 lightPos;
uniform vec3 lightColor;
uniform vec3 viewPos;

out vec4 color;

in vec4 VertexColor;
in vec3 FragPos;
in vec3 Normal;

void main() {
  // Ambient
  float ambientStrength = 0.2f;
  vec3 ambient = ambientStrength * lightColor;

  // Diffuse
  vec3 norm = normalize(Normal);
  vec3 lightDir = normalize(lightPos - FragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = diff * lightColor;

  // Specular
  float specularStrength = 0.5f;
  vec3 viewDir = normalize(viewPos - FragPos);
  vec3 reflectDir = reflect(-lightDir, norm);
  float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
  vec3 specular = specularStrength * spec * lightColor;

  vec3 result = (ambient + diffuse + specular) * mix(material.diffuse, vec3(VertexColor), VertexColor[3]);
  color = vec4(result, material.opacity);
}
]]

local DEFAULT_DEPTH_VERTEX_SHADER = [[#version 330 core
layout (location = 0) in vec3 position;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
void main() {
  gl_Position = projection * view * model * vec4(position, 1.0f);
}
]]

local DEFAULT_DEPTH_FRAGMENT_SHADER = [[#version 330 core
out float color;
void main() {
  color = 1.0 / gl_FragCoord.w;
}
]]


function xgl.init(show_window, window_width, window_height)
  xgl.lib.xgl___init(show_window or false, window_width or 16, window_height or 16)
end

function xgl.terminate()
  xgl.lib.xgl___terminate()
end

function xgl.pollEvents()
  xgl.lib.xgl___pollEvents()
end

function xgl.windowShouldClose()
  return xgl.lib.xgl___windowShouldClose()
end

function xgl.getDefaultShader()
  if default_shader == nil then
    default_shader = xgl.Shader()
    default_shader:create(DEFAULT_VERTEX_SHADER, DEFAULT_FRAGMENT_SHADER)
  end
  return default_shader
end

function xgl.getDefaultMaterial()
  if default_material == nil then
    default_material = xgl.Material(xgl.getDefaultShader(), {0,0.5,0,1})
  end
  return default_material
end

function xgl.getDefaultDepthShader()
  if default_depth_shader == nil then
    default_depth_shader = xgl.Shader()
    default_depth_shader:create(DEFAULT_DEPTH_VERTEX_SHADER, DEFAULT_DEPTH_FRAGMENT_SHADER)
  end
  return default_depth_shader
end

function xgl.getDefaultDepthMaterial()
  if default_depth_material == nil then
    default_depth_material = xgl.Material(xgl.getDefaultDepthShader(), {1,1,1,1})
  end
  return default_depth_material
end

function xgl.scale(x, y, z)
  if type(x) == 'table' or torch.isTensor(x) then
    x,y,z = x[1],x[2],x[3]
  end
  y = y or x
  z = z or x
  local S = torch.eye(4)
  S[{1,1}] = x
  S[{2,2}] = y
  S[{3,3}] = z
  return S
end

function xgl.translate(x, y, z)
  if type(x) == 'table' or torch.isTensor(x) then
    x,y,z = x[1],x[2],x[3]
  end
  local T = torch.eye(4)
  T[{1,4}] = x
  T[{2,4}] = y
  T[{3,4}] = z
  return T
end

function xgl.rotateEuler(x, y, z, deg)
  if type(x) == 'table' or torch.isTensor(x) then
    x,y,z = x[1],x[2],x[3]
    deg = y
  end
  if deg then
    x = math.rad(x)
    y = math.rad(y)
    z = math.rad(z)
  end
  local cos,sin = math.cos,math.sin
  local X = torch.DoubleTensor({
    {       1,       0,       0,        0 },
    {       0,  cos(x), -sin(x),        0 },
    {       0,  sin(x),  cos(x),        0 },
    {       0,       0,       0,        1 }
  })
  local Y = torch.DoubleTensor({
    {  cos(y),       0,  sin(y),       0 },
    {       0,       1,       0,       0 },
    { -sin(y),       0,  cos(y),       0 },
    {       0,       0,       0,       1 }
  })
  local Z = torch.DoubleTensor({
    {  cos(z), -sin(z),       0,       0 },
    {  sin(z),  cos(z),       0,       0 },
    {       0,       0,       1,       0 },
    {       0,       0,       0,       1 }
  })
  return X * Y * Z
end

function xgl.rotateAxis(axis, theta, deg)
  if not torch.isTensor(axis) then
    axis = torch.DoubleTensor(axis)
  end
  if deg then
    theta = math.rad(theta)
  end
  local n = axis:norm()
  if n == 0 then
    error('axis must not be the null vector')
  end
  local u = torch.div(axis, n)
  local ct, st = math.cos(theta), math.sin(theta)
  local d = 1-ct
  local R = torch.DoubleTensor({
    {      ct+u[1]*u[1]*d, u[1]*u[2]*d-u[3]*st, u[1]*u[3]*d+u[2]*st, 0 },
    { u[2]*u[1]*d+u[3]*st,      ct+u[2]*u[2]*d, u[2]*u[3]*d-u[1]*st, 0 },
    { u[3]*u[1]*d-u[2]*st, u[3]*u[2]*d+u[1]*st,      ct+u[3]*u[3]*d, 0 },
    { 0, 0, 0, 1 },
  })
  return R
end

return xgl
