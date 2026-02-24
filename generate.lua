-- =============================================================================

-- Ensure 'mini' accessibility
local cwd = vim.fn.getcwd()
local mini_dir = cwd .. '/.deps/mini.nvim'
vim.opt.runtimepath:prepend(mini_dir)
local MiniHues = require('mini.hues')
local MiniColors = require('mini.colors')

local hl_set = vim.api.nvim_set_hl
local hl_get = vim.api.nvim_get_hl

-- =============================================================================

-- Derive a highlight group from a reference one
local hl_derive = function(name, name_ref, changes)
  changes = changes or {}
  local ns = changes.ns or 0

  local data = hl_get(ns, { name = name_ref, link = false })
  for _, change in ipairs(changes) do
    for key, val in pairs(change) do
      if val == false then
        data[key] = nil
      elseif data[val] ~= nil then
        data[key] = data[val]
      else
        data[key] = val
      end
    end
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  hl_set(ns, name, data)
end

-- Create a color palette from a given color hue
local palette_create = function(hue)
  local bg = MiniColors.convert({ l = 15, c = 3, h = hue }, 'hex')
  local fg = MiniColors.convert({ l = 85, c = 3, h = hue }, 'hex')

  local palette = MiniHues.make_palette({
    background = bg,
    foreground = fg,
    n_hues = 8,
    accent = 'bg',
    saturation = 'medium'
  })
  palette._ = { hue = hue }
  return palette
end

-- Define highlight groups from a color palette
local hl_from_palette = function(palette)
  vim.cmd('highlight clear')
  MiniHues.apply_palette(palette)

  for key, val in pairs(palette) do
    if key ~= '_' then
      hl_set(0, 'palette.fg.' .. key, { fg = val })
      hl_set(0, 'palette.bg.' .. key, { bg = val })
    end
  end
end

-- Adjust highlight groups
local hl_adjust = function()
  hl_derive('MiniJump', 'Normal', {
    { bg = false }, { sp = 'fg' }, { bold = true }, { undercurl = true }
  })

  hl_set(0, 'FlashMatch', { link = 'MiniJump' })
end

-- Provide a highlight groups filetring function
local hl_filter_func = function(names, attrs)
  names = (type(names) ~= 'table') and { names } or names
  attrs = (type(attrs) ~= 'table') and { attrs } or attrs

  return function(_, data)
    local match_name = (#names == 0)
    local match_attr = (#attrs == 0)
    if not match_name then
      for _, name in ipairs(names) do
        if data.name:find(name) then match_name = true break end
      end
    end
    if match_name and (not match_attr) then
      for _, attr in ipairs(attrs) do
        if data.attr == attr then match_attr = true break end
      end
    end
    return match_name and match_attr
  end
end

-- Tweak a colorscheme
local scheme_tweak = function(scheme)
  local add = function(chan, val, names, attrs)
    local add = (type(val) == 'string') and (tonumber(val) ~= nil)
    local func = add and 'chan_add' or 'chan_set'
    val = add and tonumber(val) or val

    scheme = scheme[func](scheme, chan, val, {
      filter = hl_filter_func(names, attrs)
    })
  end
  local lighten = function(v, n, a) add('lightness', v, n, a) end

  lighten(95, '^MiniJump$', { 'fg', 'sp' })

  return scheme
end

-- Create a colorscheme object from a given color palette
local scheme_create = function(palette)
  hl_from_palette(palette)
  hl_adjust()
  local scheme =  MiniColors.get_colorscheme(nil, {
    new_name = 'minihuit-' .. palette._.hue
  })
  scheme._ = { palette = palette }
  scheme = scheme_tweak(scheme)
  return scheme
end

-- =============================================================================

for _, hue in ipairs({ 180 }) do
  print(string.format("[generate.lua] Hue=%u", hue))

  local sch = scheme_create(palette_create(hue))
  sch:write({ directory = cwd .. '/colors' })
end
