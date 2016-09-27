local xgl = require 'xgl'

xgl.init(true, 640, 480)

local scene = xgl.SimpleScene()
local camera = xgl.Camera()

camera:setProjectionMatrix(camera.perspective(1, 640/480, 0.01, 10.0))
camera:lookAt({0,0,-1.5}, {0,0,0}, {0,-1,0})
scene:setCamera(camera)


disk = xgl.geo.disk(0.5, 32)
local disk_material = disk:getMeshAt(1):getMaterial()
disk_material:setFacetCulling(true)
disk_material:setDiffuseColor({1,1,1,1})

scene:addModel(disk)
scene:setClearColor(0,0,0.5,1)

local p0 = torch.Tensor({0, 0, -1.5, 1})

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
