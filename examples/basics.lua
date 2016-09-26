xgl = require 'xgl'
image = require 'image'

xgl.init()

local w,h = 640, 480
  
local scene = xgl.SimpleScene()
  
local camera = xgl.Camera()
camera:setIntrinsics(1000, 1000, 320, 240, w, h)
camera:lookAt({0,-0.5,0.4}, {0,0,0}, {0,1,0})

print('Projection:')
print(camera:getProjectionMatrix())
print('View:')
print(camera:getViewMatrix())
print('Camera pose:')
print(camera:getPose())
print('Intrinsic matrix:')
print(camera:getIntrinsicMatrix())

local shader = xgl.Shader("../shaders/Basic.VertexShader.glsl", "../shaders/BasicLighting.FragmentShader.glsl")
print('shader loaded..')
local model = xgl.Model(shader, "data/0901.stl")

model:getMeshAt(1):getMaterial():setDiffuseColor({0,1,0,1})

print('Model pose (4x4 matrix):')
print(model:getPose())
  
scene:setCamera(camera)
scene:addModel(model)

scene:setClearColor(1,0,0,1)
scene:render()
  
local t = camera:copyRenderResult()

print(t[{1,{1,10}}])
print(t:size())

image.savePNG('blub.png', t:permute(3,1,2))

xgl.terminate()
