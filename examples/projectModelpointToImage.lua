xgl = require 'xgl'
image = require 'image'

xgl.init()

-- set with and height of output image
local w,h = 640, 480

-- initialize a szene
local scene = xgl.SimpleScene()



-- load shader and 3d model of object and set color of object
local shader = xgl.Shader("../shaders/Basic.VertexShader.glsl", "../shaders/BasicLighting.FragmentShader.glsl")
local model = xgl.Model(shader, "data/0901.stl")
model:getMeshAt(1):getMaterial():setDiffuseColor({0,1,0,1})

-- get list of vertices
local listOfVertices = model:getMeshAt(1):getVertices()

-- get coordinates of first vertex
local vertex = listOfVertices[{{1},{1,3}}]:double():t()

print ('The extracted vertex` coordinates relative to the model origin:')
print ('(' .. torch.round(vertex[{1,1}]*10000)/10000 .. ',' .. torch.round(vertex[{2,1}]*10000)/10000 .. ',' .. torch.round(vertex[{3,1}]*10000)/10000 .. ')')

-- the model has a certain pose relative to the world coordinate system. It can be rotated, translated and sheared
-- we rotate the model 0.05 PI around the z-axis and get the according transformation matrix
model:setPose(xgl.rotateAxis({0,0,1}, 0.05*math.pi))
local modelPose = model:getPose();

print ('The matrix to transform model coordinates to world coordinates is:')
print (modelPose)

-- we can now transform the vertex coordinates into the world by transforming the vertex into homogeneous coordinates 
-- and then multiply with the modelPose. We z-coordinates will not change, because we rotate around the z-axis

-- add 1 at the end for homogeneous coordinates
vertexH = torch.cat(vertex,torch.eye(1),1);

vertexWorld = modelPose * vertexH

print ('The vertex` coordinates in the world are:')
print ('(' .. torch.round(vertexWorld[{1,1}]*10000)/10000 .. ',' .. torch.round(vertexWorld[{2,1}]*10000)/10000 .. ',' .. torch.round(vertexWorld[{3,1}]*10000)/10000 .. ')')

-- we initialize the camera with focal length and principal point
local focalLength = 1000
local pX = 320
local pY = 240

local camera = xgl.Camera()
camera:setIntrinsics(focalLength, focalLength, pX, pY, w, h)

-- the camera has its own camera world. In the camera world, the camera center is the origin of the coordinate system. 
-- the cameraPosition defines a real world point where camera is located and lookAtPoint defines a direction for the camera to look at
-- the connection between cameraPosition and lookAtPoint defines the -z axis in the camera coordinate system
local cameraPosition = torch.DoubleTensor({0,0,0.5}) --the camera watches from above
local lookAtPoint = torch.DoubleTensor({0,0,0}) --to the origin of the world system
local whereIsUp = torch.DoubleTensor({0,1,0})
camera:lookAt(cameraPosition, lookAtPoint, whereIsUp)

-- similar to the model the camera has a certain pose relative to the world coordinate system. This pose is calcualted from cameraPosition and lookAtPoint
local cameraPose = camera:getPose();
print ('The matrix to transform camera coordinates to world coordinates is:')
print(cameraPose)

-- using the cameraPose we can transform a point in the camera system to the world. But we want the inserse, namely to transform
-- a world point into the camera system
vertexCamera = torch.inverse(cameraPose) * vertexWorld
print ('The vertex` coordinates in the camera system are:')
print ('(' .. torch.round(vertexCamera[{1,1}]*10000)/10000 .. ',' .. torch.round(vertexCamera[{2,1}]*10000)/10000 .. ',' .. torch.round(vertexCamera[{3,1}]*10000)/10000 .. ')')

-- usually models are built watching along the positive z-axis, but the camera watches towards the negative z-axis
-- therefore, we have to rotate the point around the x-axis
local rotationXAxis = torch.eye(4)
rotationXAxis[{2,2}] = -1
rotationXAxis[{3,3}] = -1

vertexCameraR = rotationXAxis * vertexCamera
print ('The rotated vertex` coordinates in the camera system are:')
print ('(' .. torch.round(vertexCameraR[{1,1}]*10000)/10000 .. ',' .. torch.round(vertexCameraR[{2,1}]*10000)/10000 .. ',' .. torch.round(vertexCameraR[{3,1}]*10000)/10000 .. ')')

-- finally, we can project the point onto the image using the camera matrix
-- the camera matrix does the projection of the 3d world point onto the image
-- it contains the principal point of the camera and focal length's
local middleMatrix = torch.Tensor(3,4);
middleMatrix[1][1] = 1;
middleMatrix[2][2] = 1;
middleMatrix[3][3] = 1;

local cameraMatrix = camera:getIntrinsicMatrix() * middleMatrix;

print(cameraMatrix)

-- we can project by multiplying but have to divide by the 3rd coordinate to normalize
local projectedVertex = cameraMatrix * vertexCameraR
projectedVertex:div(projectedVertex[{3,1}])

print ('The coordinates of the vertex on the image are:')
print ('(' .. torch.round(projectedVertex[{1,1}]*10000)/10000 .. ',' .. torch.round(projectedVertex[{2,1}]*10000)/10000 .. ')')

-- finally, we can render the full scene
scene:setCamera(camera)
scene:addModel(model)

scene:setClearColor(1,1,0,1)
scene:render()

local t = camera:copyRenderResult()

image.savePNG('testimageProjection.png', t:permute(3,1,2))