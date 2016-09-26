local xgl = require 'xgl'
local utils = require 'xgl.utils'

xgl.init(true, 640, 480)

local scene = xgl.SimpleScene()

local camera = xgl.Camera()
camera:setImageSize(1024, 768)
camera:setProjectionMatrix(camera.perspective(1, camera:getAspectRatio(), 0.01, 10.0))
camera:lookAt({4,0.5,2}, {0,0,0}, {0,1,0})

scene:setCamera(camera)
scene:setClearColor(1,0,0,1)

local model = xgl.geo.sphere(2, 3)
model:getMeshAt(1):getMaterial():setFacetCulling(true)
scene:addModel(model)

local p0 = torch.Tensor({4,0.5,2,1})

while not xgl.windowShouldClose() do
  local t = sys.clock()
  
  local theta = t%(2*math.pi)
  local eye = xgl.rotateAxis({0,1,0}, theta) * p0
  
  camera:lookAt(eye[{{1,3}}], {0,0,0}, {0,1,0})  
  
  scene:render()
  camera:swapBuffers()
  xgl.pollEvents()
  sys.sleep(0.01)
end

xgl.terminate()
