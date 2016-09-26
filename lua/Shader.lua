local torch = require 'torch'
local xgl = require 'xgl.env'
local utils = require 'xgl.utils'

local Shader = torch.class('xgl.Shader', xgl)

function init()
  local method_names = {
    'new',
    'delete',
    'release',
    'create',
    'load'
  }

  return utils.create_method_table('xgl_Shader_', method_names)
end

local f = init()

function Shader.createUnassigned()
  local obj = torch.factory('xgl.Shader')()
  obj.o = f.new()
  return obj
end

function Shader:__init(vertex_shader_path, fragment_shader_path)
  self.o = f.new()
  if vertex_shader_path ~= nil and fragment_shader_path ~= nil then
    self:load(vertex_shader_path, fragment_shader_path)
  end
end

function Shader:cdata()
  return self.o
end

function Shader:release()
  f.release(self.o)
end

function Shader:isNull()
  return f.isNull(self.o)
end

function Shader:create(vertex_shader_source, fragment_shader_source)
  f.create(self.o, vertex_shader_source, fragment_shader_source)
end

function Shader:load(vertex_shader_path, fragment_shader_path)
  f.load(self.o, vertex_shader_path, fragment_shader_path)
end
