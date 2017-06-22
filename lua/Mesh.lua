local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local Mesh = torch.class('xgl.Mesh', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'create',
    'release',
    'isNull',
    'getVertices',
    'getMaterial',
    'setMaterial'
  }

  return utils.create_method_table('xgl_Mesh_', method_names)
end

local f = init()

function Mesh.createUnassigned()
  local obj = torch.factory('xgl.Mesh')()
  obj.o = f.new()
  return obj
end

function Mesh:__init(vertices, indices, material)
  self.o = f.new()
  f.create(self.o, vertices:cdata(), indices:cdata(), utils.cdata(material))
end

function Mesh:cdata()
  return self.o
end

function Mesh:release()
  f.release(self.o)
end

function Mesh:isNull()
  return f.isNull(self.o)
end

function Mesh:getVertices()
  local vertices = torch.FloatTensor()
  f.getVertices(self.o, vertices:cdata())
  return vertices
end

function Mesh:getMaterial()
  local material = xgl.Material.createUnassigned()
  f.getMaterial(self.o, material:cdata())
  return material
end

function Mesh:setMaterial(value)
  f.setMaterial(self.o, utils.cdata(value))
end
