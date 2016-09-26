local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local Material = torch.class('xgl.Material', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'create',
    'release',
    'isNull',
    'getDiffuseColor',
    'setDuffuseColor',
    'getShader',
    'setShader',
    'getShininess',
    'setShininess',
    'getOpacity',
    'setOpacity',
    'getFacetCulling',
    'setFacetCulling',
    'getDepthTest',
    'setDepthTest',
    'getDepthWrite',
    'setDepthWrite',
    'updateTextureRGB8'
  }

  return utils.create_method_table('xgl_Material_', method_names)
end

local f = init()

function Material.createUnassigned()
  local obj = torch.factory('xgl.Material')()
  obj.o = f.new()
  return obj
end

function Material:__init(shader, diffuse_color)
  self.o = f.new()
  f.create(self.o)
  if shader ~= nil then
    self:setShader(shader)
  end
  if diffuseColor ~= nil then
    self:setDiffuseColor(diffuse_color)
  end
end

function Material:cdata()
  return self.o
end

function Material:release()
  f.release(self.o)
end

function Material:isNull()
  return f.isNull(self.o)
end

function Material:getDiffuseColor()
  local color = torch.FloatTensor()
  f.getDiffuseColor(self.o, color:cdata())
  return color
end
    
function Material:setDiffuseColor(color)
  if type(color) == 'table' then
    color = torch.FloatTensor(color)
  end
  color = color:float()
  f.setDuffuseColor(self.o, color:cdata())
end

function Material:getShader()
  local shader = xgl.Shader.createUnassigned()
  f.getShader(self.o, shader:cdata())
  return shader
end

function Material:setShader(shader)
  f.setShader(self.o, utils.cdata(shader))
end
    
function Material:getShininess()
  return f.getShininess(self.o)
end

function Material:setShininess(value)
  f.setShininess(self.o, value)
end
    
function Material:getOpacity()
  return f.getOpacity(self.o)
end

function Material:setOpacity(value)
  f.setOpacity(self.o, value)
end
    
function Material:getFacetCulling()
  return f.getFacetCulling(self.o)
end
    
function Material:setFacetCulling(value)
  f.setFacetCulling(self.o, value)
end

function Material:getDepthTest()
  return f.getDepthTest(self.o)
end

function Material:setDepthTest(value)
  f.setDepthTest(self.o, value)    
end

function Material:getDepthWrite()
  return f.getDepthWrite(self.o)
end

function Material:setDepthWrite(value)
  f.setDepthWrite(self.o, value)
end

function Material:updateTextureRGB8(index, width, height, image, flipV, generateMipmap)
  f.updateTextureRGB8(self.o, index, width, height, image:cdata(), flipV ~= nil and flipV or false, generateMipmap or false)
end
