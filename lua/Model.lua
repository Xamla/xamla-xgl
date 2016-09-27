local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local Model = torch.class('xgl.Model', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'loadModel',
    'getPose',
    'setPose',
    'addMesh',
    'addMesh_Tensor',
    'getMeshCount',
    'getMeshAt'
  }

  return utils.create_method_table('xgl_Model_', method_names)
end

local f = init()

function Model:__init(default_shader, model_filename)
  default_shader = default_shader or xgl.getDefaultShader()
  self.o = f.new(default_shader:cdata())
  if model_filename ~= nil then
    self:loadModel(model_filename)
  end
end

function Model:cdata()
  return self.o
end

function Model:loadModel(filename)
  f.loadModel(self.o, filename)
end

function Model:getPose(output)
  output = output or torch.DoubleTensor()
  f.getPose(self.o, output:cdata())
  return output
end

function Model:setPose(pose)
  f.setPose(self.o, pose:cdata())
end

function Model:addMesh(vertices, indices, shader, color)
  if torch.isTypeOf(vertices, xgl.Mesh) then
    f.addMesh(self.o, vertices:cdata())
  else
    color = color or torch.FloatTensor(1,1,1,1)
    if type(color) == 'table' then
      color = torch.FloatTensor(color)
    end
    color = color:float()
    f.addMesh_Tensor(self.o, vertices:cdata(), indices:cdata(), utils.cdata(shader), color:cdata())
  end
end

function Model:getMeshCount()
  return f.getMeshCount(self.o)
end

function Model:getMeshAt(index)
  local mesh = xgl.Mesh.createUnassigned()
  f.getMeshAt(self.o, index-1, mesh:cdata())
  return mesh
end
