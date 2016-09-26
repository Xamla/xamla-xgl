local xgl = require 'xgl'

xgl.init(true, 640, 480)

local scene = xgl.SimpleScene()
local camera = xgl.Camera()

camera:setProjectionMatrix(camera.perspective(1, 640/480, 0.01, 10.0))
camera:lookAt({0,-1,-1.5}, {0,0,0}, {0,-1,0})
scene:setCamera(camera)


function circlePointsXZ(n, radius, center)
  radius = radius or 1
  center = center or torch.FloatTensor(3):zero()
  if type(center) == 'table' then
    center = torch.FloatTensor(center)
  end
  
  local points = torch.FloatTensor(n, 3)
  local rotor = torch.FloatTensor({1,0,0}) * radius
  for i=1,n do
    local frac = (i-1) / n
    local angle = frac * 2 * math.pi
    
    local c,s = math.cos(angle), math.sin(angle)
    
    local R = torch.FloatTensor({
      {c, 0, -s},
      {0, 1, 0},
      {s, 0, c}}
    )
    
    points[i] = center + R * rotor
  end
  return points
end


function generateCylinderMesh(n, height, radius)
  --local vertices = torch.FloatTensor(2 + n*2, 12):zero()
  local vertices = torch.rand(2 + n * 2, 12):float()
  local indices = {}
  
  local top_center = torch.FloatTensor({0,height/2,0})
  local bottom_center = torch.FloatTensor({0,-height/2,0})
  
  vertices[{1,{1,3}}] = top_center
  vertices[{{2,n+1},{1,3}}] = circlePointsXZ(n, radius, top_center)
  
  vertices[{n+2,{1,3}}] = bottom_center
  vertices[{{n+3,n*2+2},{1,3}}] = circlePointsXZ(n, radius, bottom_center)
  
  local function addDiskIndices(center, first, last, reverse)
    local j = last
    for i=first,last do
      
      if not reverse then
        table.insert(indices, center)
        table.insert(indices, i)
        table.insert(indices, j)
      else
        table.insert(indices, j)
        table.insert(indices, i)
        table.insert(indices, center)
      end
      
      j = i
    end
  end
  
  addDiskIndices(0, 1, n, false)    -- top disk

  -- side
  local stride = n + 1
  local j = n
  for i=1, n do
    table.insert(indices, i + stride)
    table.insert(indices, j)
    table.insert(indices, i)
    
    table.insert(indices, j)
    table.insert(indices, i + stride)
    table.insert(indices, j + stride)
    
    j = i
  end

  addDiskIndices(n + 1, n + 2, n * 2 + 1, true)   -- bottom disk
  
  return vertices, torch.IntTensor(indices)
end


function createQuadMesh(xdim, ydim)
  xdim,ydim = xdim*0.5,ydim*0.5
  vertices = torch.FloatTensor({
    { -xdim,  ydim, 0.0,   0.0, 0.0, 1.0,   0.0, 1.0,   0.0, 0.0, 0.0 },
    { -xdim, -ydim, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0,   0.0, 0.0, 0.0 },
    {  xdim,  ydim, 0.0,   0.0, 0.0, 1.0,   1.0, 0.0,   0.0, 0.0, 0.0 },
    {  xdim, -ydim, 0.0,   0.0, 0.0, 1.0,   1.0, 1.0,   0.0, 0.0, 0.0 }
  })

  indices = torch.IntTensor(
  { 
    0, 1, 2,
    2, 1, 3
  })
  return vertices, indices
end

local vertices, indices = generateCylinderMesh(16, 1, 0.2)
--local vertices, indices = createQuadMesh(1, 1)
local shader = xgl.Shader("../shaders/Paper.VertexShader.glsl", "../shaders/BasicLighting.FragmentShader.glsl")

model = xgl.Model(shader)
model:addMesh(vertices, indices, shader, {0,1,0,1})
model:getMeshAt(1):getMaterial():setFacetCulling(true)
scene:addModel(model)
scene:setClearColor(0,0,0.5,1)

local p0 = torch.Tensor({1,1.2,0.2,1})
  
while not xgl.windowShouldClose() do
  local t = sys.clock()
  
  local theta = t--%(2*math.pi)
  local eye = xgl.rotateAxis({0,0,1}, theta) * p0

  camera:lookAt(eye[{{1,3}}], {0,0,0}, {0,1,0})  
  
  scene:render()  
  camera:swapBuffers()
  xgl.pollEvents()
  sys.sleep(0.01)
end


xgl.terminate()
