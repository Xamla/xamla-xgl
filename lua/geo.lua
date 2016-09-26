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
