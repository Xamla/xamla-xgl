local ffi = require 'ffi'
local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local SimpleScene = torch.class('xgl.SimpleScene', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'render',
    'renderDepth',
    'setClearColor',
    'getOverrideMaterial',
    'setOverrideMaterial',
    'setCamera',
    'addModel',
    'clearModels',
    'addQuad'
  }

  return utils.create_method_table('xgl_SimpleScene_', method_names)
end

local f = init()

function SimpleScene:__init()
  self.o = f.new()
end

function SimpleScene:cdata()
  return self.o
end

function SimpleScene:render()
  f.render(self.o)
end

function SimpleScene:renderDepth(clear_depth, depth_material, output)
  clear_depth = clear_depth or 0/0
  self:setClearColor(clear_depth, 0, 0, 1)
  depth_material = depth_material or xgl.getDefaultDepthMaterial()
  local old_override_material = self:getOverrideMaterial()
  self:setOverrideMaterial(depth_material)
  f.renderDepth(self.o)
  local depth_image = self.camera:copyRenderResultF32(false, output)
  self:setOverrideMaterial(old_override_material)
  return depth_image
end

function SimpleScene:setClearColor(r, g, b, a)
  f.setClearColor(self.o, r, g, b, a)
end

function SimpleScene:getOverrideMaterial()
  local material = xgl.Material.createUnassigned()
  f.getOverrideMaterial(self.o, material:cdata())
  if material:isNull() then
    return nil
  else
    return material
  end
end

function SimpleScene:setOverrideMaterial(value)
  f.setOverrideMaterial(self.o, utils.cdata(value))
end
    
function SimpleScene:setCamera(camera)
  self.camera = camera
  f.setCamera(self.o, camera:cdata())
end

function SimpleScene:addModel(model)
  f.addModel(self.o, model:cdata())
end

function SimpleScene:clearModels()
  f.clearModels(self.o)
end

function SimpleScene:addQuad(xdim, ydim, shader, texture_filename, opacity, depth_write)
  local model = xgl.Model(shader)
  if depth_write == nil then
    depth_write = true
  end
  print(depth_write)
  f.addQuad(self.o, model:cdata(), xdim, ydim, shader:cdata(), texture_filename, opacity or 1, depth_write)
  return model
end
