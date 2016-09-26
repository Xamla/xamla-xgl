local ffi = require 'ffi'
local xgl = require 'xgl.env'

local utils = {}

function utils.create_method_table(prefix, names)
  local map = {}
  for i,n in ipairs(names) do
    local full_name = prefix .. n
    -- use pcall since not all types support all functions
    local ok,v = pcall(function() return xgl.lib[full_name] end)
    if ok then
      map[n] = v
    end
  end

  -- check whether we have new and delete functions
  -- automatically register objects created by new with the gc
  local _new, _clone, _delete = map.new, map.clone, map.delete

  if _new and _delete then
    map.new = function(...)
      local obj = _new(...)
      ffi.gc(obj, _delete)
      return obj
    end
  end

  if _clone and _delete then
    map.clone = function(...)
      local obj = _clone(...)
      ffi.gc(obj, _delete)
      return obj
    end
  end

  return map
end

-- safe accessor for cdata()
function utils.cdata(x)
  return x and x:cdata() or ffi.NULL
end

function utils.reverse_mapping(t, r)
  for k,v in pairs(t) do
    r[v] = k
  end
  return r
end

function shallow_copy(t)
  local c = {}
  for k,v in pairs(t) do
    c[k] = v
  end
  return c
end

function utils.keys(t)
  local l = {}
  for k,v in pairs(t) do
    table.insert(l, k)
  end
  return l
end

function utils.values(t)
  local l = {}
  for k,v in pairs(t) do
    table.insert(l, v)
  end
  return l
end

function utils.shuffle_n(array, count)
  count = math.max(count, count or #array)
  local r = #array    -- remaining elements to pick from
  local j, t
  for i=1,count do
    j = math.random(r) + i - 1
    t = array[i]    -- swap elements at i and j
    array[i] = array[j]
    array[j] = t
    r = r - 1
  end
end

function utils.shuffle(array)
  local i, t
  for n=#array,2,-1 do
    i = math.random(n)
    t = array[n]
    array[n] = array[i]
    array[i] = t
  end
  return array
end

function utils.printf(...)
  return print(string.format(...))
end

return utils
