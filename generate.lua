-- =============================================================================

-- Ensure 'mini.nvim' accessibility
local cwd = vim.fn.getcwd()
local mini_dir = cwd .. '/.deps/mini.nvim'
vim.opt.runtimepath:prepend(mini_dir)

-- Define helper variables
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

-- Provide a filtering function for highlight groups and attributes
local hl_filter_func = function(names, attrs)
  names = (type(names) ~= 'table') and { names } or names
  attrs = (type(attrs) ~= 'table') and { attrs } or attrs

  return function(_, data)
    local match_name = (#names == 0)
    local match_attr = (#attrs == 0)
    if not match_name then
      for _, name in ipairs(names) do
        if data.name:find(name) then
          match_name = true
          break
        end
      end
    end
    if match_name and (not match_attr) then
      for _, attr in ipairs(attrs) do
        if data.attr == attr then
          match_attr = true
          break
        end
      end
    end
    return match_name and match_attr
  end
end

-- Modify a colorscheme's channel (eg. saturation, lightness... etc)
local sch_modify = function(sch, chan, val, names, attrs)
  local add = (type(val) == 'string') and (tonumber(val) ~= nil)
  local func = add and 'chan_add' or 'chan_set'
  val = add and tonumber(val) or val
  return sch[func](sch, chan, val, { filter = hl_filter_func(names, attrs) })
end

-- Generate a new colorscheme
local sch_generate = function(hue, name)
  name = name or string.format('minisep-%u', hue)

  -- Clear all highlighting
  vim.cmd('highlight clear')
  for i = 0, 15 do vim.g['terminal_color_' .. i] = nil end

  -- Create a color palette, and apply it
  local palette = MiniHues.make_palette({
    background = MiniColors.convert({ l = 15, c = 3, h = hue }, 'hex'),
    foreground = MiniColors.convert({ l = 85, c = 3, h = hue }, 'hex'),
    n_hues = 8,
    accent = 'bg',
    saturation = 'medium'
  })
  MiniHues.apply_palette(palette)

  -- Add custom `palette.xxx` groups exposing the palette content
  for key, val in pairs(palette) do
    hl_set(0, 'palette.' .. key, { fg = val })
  end

  -- Add/modify some highlight groups
  hl_derive('MiniJump', 'Normal', {
    { bg = false }, { sp = 'fg' }, { bold = true }, { undercurl = true }
  })
  hl_set(0, 'FlashLabel', { link = 'MiniJump' })
  hl_derive('FlashMatch', 'palette.yellow', {
    { bg = false }, { sp = 'fg' }, { bold = true }, { undercurl = true },
  })
  hl_derive('MiniPickMatchCurrent', 'MiniPickMatchCurrent', {
    { bold = true }, { undercurl = false },
  })
  hl_set(0, '@function', { link = 'palette.blue' })
  hl_derive('MiniPickMatchRanges', '@function', {
    { bold = true }, { undercurl = true },
  })
  hl_set(0, 'Function', { link = '@function' })
  hl_set(0, 'Directory', { link = '@function' })

  -- Get the colorscheme representation
  local sch = MiniColors.get_colorscheme(nil, { new_name = name })

  -- Tweak colorscheme content
  local exact = function(v) return '^' .. v .. '$' end
  sch = sch_modify(sch, 'saturation', '+15', nil, { 'fg', 'sp' })
  sch = sch_modify(sch, 'lightness', 95, exact('MiniJump'), { 'fg', 'sp' })
  sch = sch_modify(sch, 'saturation', 100, exact('FlashMatch'), { 'fg', 'sp' })

  -- Write colorscheme to file
  sch:write({ directory = cwd .. '/colors' })
end

-- =============================================================================

local hue_nb = 1
local hue_gap = 360 / (hue_nb + 1)
for i = 1, hue_nb do
  local hue = i * hue_gap
  print(string.format("[generate.lua] Generate hue='%u'", hue))
  sch_generate(hue)
end
