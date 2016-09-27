local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local geo = {}
xgl.geo = geo


local function dot(a, b)
  local y = 0
  for i=1,#a do y = y + a[i] * b[i] end
  return y
end

local function l2(v)
  return math.sqrt(dot(v, v))
end

local function mul(v, s)
  return { v[1] * s, v[2] * s, v[3] * s }
end

local function normalize(v)
  return mul(v, 1/l2(v))
end

local function range(s,e)
  local t = {}
  for i=s,e do table.insert(t, i) end
  return t
end

local function octaeder()
  local vertices = {{0,1,0}, {-1,0,1}, {1,0,1}, {1,0,-1}, {-1,0,-1}, {0,-1,0}}
  local triangles = {
    {2,3,1}, {3,4,1}, {4,5,1}, {5,2,1},
    {3,2,6}, {4,3,6}, {5,4,6}, {2,5,6}
  }

  for i,v in ipairs(vertices) do
    vertices[i] = normalize(vertices[i])
  end

  return vertices, triangles
end

local function icosahedron()
  local t = (1 + math.sqrt(5)) * 0.5
  local vertices = {
    {-1, t, 0},
    { 1, t, 0},
    {-1,-t, 0},
    { 1,-t, 0},
    { 0,-1, t},
    { 0, 1, t},
    { 0,-1,-t},
    { 0, 1,-t},
    { t, 0,-1},
    { t, 0, 1},
    {-t, 0,-1},
    {-t, 0, 1}
  }

  local triangles = {
    { 1,12, 6},
    { 1, 6, 2},
    { 1, 2, 8},
    { 1, 8,11},
    { 1,11,12},
    { 2, 6,10},
    { 6,12, 5},
    {12,11, 3},
    {11, 8, 7},
    { 8, 2, 9},
    { 4,10, 5},
    { 4, 5, 3},
    { 4, 3, 7},
    { 4, 7, 9},
    { 4, 9,10},
    { 5,10, 6},
    { 3, 5,12},
    { 7, 3,11},
    { 9, 7, 8},
    {10, 9, 2}
  }

  for i,v in ipairs(vertices) do
    vertices[i] = normalize(vertices[i])
  end

  return vertices, triangles
end

local function removeDuplicateVertices(vertices, indices)
  local remapping = {}
  local vertex_order = range(1, #vertices)
  table.sort(vertex_order, function(a, b)
    local A,B = vertices[a],vertices[b]
    for i=1,3 do
      if A[i] < B[i] then
        return true
      elseif A[i] > B[i] then
        return false
      end
    end
    return false
  end)

  local function eq(a, b)
    return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
  end

  -- remove dupes
  local new_vertices = {}
  local last
  for _,i in ipairs(vertex_order) do
    local v = vertices[i]
    if not eq(v, last) then
      new_vertices[#new_vertices+1] = v
      last = v
    end
    remapping[i] = #new_vertices
  end

  -- apply remapping
  for i,idx in ipairs(indices) do
    indices[i] = remapping[idx]
  end

  return new_vertices, indices
end

local function generateSphereMesh(radius, subdivision_level)
  local vertices, triangles = icosahedron()

  local function halfway(a,b)
    return { 0.5 * (a[1]+b[1]), 0.5 * (a[2]+b[2]), 0.5 * (a[3]+b[3]) }
  end

  local function subdivide(triangle_index)
    local a,b,c = table.unpack(triangles[triangle_index])
    local v0,v1,v2 = vertices[a],vertices[b],vertices[c]
    local v3,v4,v5 = normalize(halfway(v0,v1)),normalize(halfway(v1,v2)),normalize(halfway(v2,v0))
    table.insert(vertices, v3)
    local d = #vertices
    table.insert(vertices, v4)
    local e = #vertices
    table.insert(vertices, v5)
    local f = #vertices
    triangles[triangle_index] = {a,d,f}
    table.insert(triangles, {f,d,e})
    table.insert(triangles, {e,d,b})
    table.insert(triangles, {e,c,f})
  end

  -- normalize octaeder vertices
  for i,v in ipairs(vertices) do
    vertices[i] = normalize(v)
  end

  local next_list = nil

  for i=1,subdivision_level do
    local count = #triangles
    for j=1,count do
      subdivide(j)
    end
  end

  local indices = {}
  for i,t in ipairs(triangles) do
    indices[#indices+1] = t[1]
    indices[#indices+1] = t[2]
    indices[#indices+1] = t[3]
  end

  vertices, indices = removeDuplicateVertices(vertices, indices)

  -- generate final vertex & index buffer
  local vertex_buffer = torch.FloatTensor():rand(#vertices, 12)
  local index_buffer = torch.IntTensor(#triangles * 3)

  for i,v in ipairs(vertices) do
    vertex_buffer[{i,{1,3}}] = torch.FloatTensor(vertices[i]) * radius    -- position
    vertex_buffer[{i,{4,6}}] = torch.FloatTensor(vertices[i])             -- normal
  end

  vertex_buffer[{{},{12}}] = 1
  index_buffer = torch.IntTensor(indices)
  index_buffer:csub(1)

  return vertex_buffer, index_buffer
end

local function circlePoints(n, center, rotor, rotatation_matrix_fn)
  radius = radius or 1
  center = center or torch.FloatTensor(3):zero()
  if type(center) == 'table' then
    center = torch.FloatTensor(center)
  end

  local points = torch.FloatTensor(n, 3)
  for i=1,n do
    local frac = (i-1) / n
    local angle = frac * 2 * math.pi
    local R = rotatation_matrix_fn(angle)
    points[i] = center + R * rotor
  end
  return points
end

-- rotate around y-axis
local function circlePointsXZ(n, center, radius)
  local rotor = torch.FloatTensor({1,0,0}) * radius
  return circlePoints(n, center, rotor, function(angle)
    local c,s = math.cos(angle), math.sin(angle)
    return torch.FloatTensor({
      {  c,  0, -s },
      {  0,  1,  0 },
      {  s,  0,  c }
    })
  end)
end

-- rotate around z-axis
local function circlePointsXY(n, center, radius)
  local rotor = torch.FloatTensor({1,0,0}) * radius
  return circlePoints(n, center, rotor, function(angle)
    local c,s = math.cos(angle), math.sin(angle)
    return torch.FloatTensor({
      {  c, -s,  0 },
      {  s,  c,  0 },
      {  0,  0,  1 }
    })
  end)
end

local function generateDiskMesh(radius, segment_count)
  radius = radius or 1
  segment_count = segment_count or 32
  local vertices = torch.FloatTensor(segment_count + 1, 12):zero()
  local vertices = torch.rand(segment_count + 1, 12):float()
  vertices[{1,{1,3}}]:zero()
  vertices[{{2,segment_count+1},{1,3}}] = circlePointsXY(segment_count, {0,0,0}, radius)
  vertices[{{1,segment_count+1},{4,6}}] = torch.FloatTensor({0,0,1}):repeatTensor(vertices:size(1),1)     -- normals
  vertices[{{1,segment_count+1},{9,12}}] = 1   -- default color white

  local indices = torch.IntTensor(3 * segment_count)

  local j = segment_count -- last
  for i=1,segment_count do
    indices[i*3-2] = 0
    indices[i*3-1] = i
    indices[i*3-0] = j
    j = i
  end

  return vertices, indices
end

--[[
function geo.cuboidMesh(width, height, thickness, material)
  local vertices = torch.FloatTensor(6 * 4) -- each side of box get individual normals
  local indices = torch.IntTensor(6 * 4 * 2)

end

function geo.cuboid(width, height, thickness, material)
  material = material or xgl.getDefaultMaterial()
  local model = xgl.Model(material:getShader())
  local mesh = geo.cuboidMesh(width, height, thickness, material)
  model:addMesh(mesh)
  return model
end

function geo.cubeMesh(side_length, material)
  return geo.cuboidMesh(side_length, side_length, side_length, material)
end]]

function geo.diskMesh(radius, segment_count, material)
  local vertices, indices = generateDiskMesh(radius, segment_count)
  return xgl.Mesh(vertices, indices, material)
end

function geo.disk(radius, segment_count, matrerial)
  material = material or xgl.getDefaultMaterial()
  local model = xgl.Model(material:getShader())
  local mesh = geo.diskMesh(radius, segment_count, material)
  model:addMesh(mesh)
  return model
end

function geo.sphereMesh(radius, subdivision_level, material)
  local vertices, indices = generateSphereMesh(radius or 1, subdivision_level or 3)
  return xgl.Mesh(vertices, indices, material)
end

function geo.sphere(radius, subdivision_level, material)
  material = material or xgl.getDefaultMaterial()
  local model = xgl.Model(material:getShader())
  local mesh = geo.sphereMesh(radius, subdivision_level, material)
  model:addMesh(mesh)
  return model
end
