local xgl = require 'xgl'
local image = require 'image'
local pcl = require 'pcl'

xgl.init()

local w,h = 640, 480

local scene = xgl.SimpleScene()

local camera = xgl.Camera()
camera:setIntrinsics(1000, 1000, 320, 240, w, h)
--camera:lookAt({0,-0.4,-0.5}, {0,0,0}, {0,-1,0})
camera:lookAt({0,-0.5,-0.0}, {0,0,0}, {0,0,-1})

print('Projection:')
print(camera:getProjectionMatrix())
print('Inverse Projection:')
print(torch.inverse(camera:getProjectionMatrix()))
print('View:')
print(camera:getViewMatrix())
print('Camera pose:')
print(camera:getPose())
print('Intrinsic matrix:')
print(camera:getIntrinsicMatrix())


local shader = xgl.Shader("../shaders/Basic.VertexShader.glsl", "../shaders/BasicLighting.FragmentShader.glsl")
local model = xgl.Model(shader, "data/0901.stl")
model:setPose(xgl.rotateAxis({1,0,0}, 0.5*math.pi))
model:getMeshAt(1):getMaterial():setDiffuseColor({0,1,0,1})

--[[local p = model:getPose()
p[{3,4}] = p[{3,4}] - 0.1
model:setPose(p)]]

print('Model pose:')
print(model:getPose())

scene:setCamera(camera)
scene:addModel(model)


-- render depth image (internally an override-material will be set with a shader that writes depth values to the red-channel)
local depth_image = scene:renderDepth(0.5) -- it is also possible to set the red channel to nan by passing 0/0 as depth_clear value

-- render color image
scene:render()
local color_image = camera:copyRenderResult(false)

-- compine depth and color image into a XYZRGBA point cloud
local cloud = pcl.PointCloud('xyzrgba', camera:getWidth(), camera:getHeight())
local points = cloud:points()


camera:unprojectDepthImage(depth_image, points, points:stride(2))
cloud:writeRGB(color_image, true, 255)

-- show point cloud in viewer
local viewer = pcl.CloudViewer()
viewer:showCloud(cloud)

print("press enter to continue...")
io.read()

print(string.format('Output size: %s', depth_image:size()))
print(string.format('Depth range: %f - %f', depth_image:min(), depth_image:max()))

-- normalize image
depth_image:csub(depth_image:min())
depth_image:div(depth_image:max())

image.savePNG('depth.png', depth_image)
print('normalized depth output has been written to "depth.png".')

image.savePNG('color.png', color_image:permute(3,1,2))
print('color image has been written to "color.png".')

cloud:savePCDFile('cloud.pcd')
print('point cloud has been written to "cloud.pcd".')

xgl.terminate()
