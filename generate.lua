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
local hl_derive = function(ns, name, name_ref, changes)
  changes = changes or {}
  changes.clear = (changes.clear == nil) and true or changes.clear
  local data = changes.clear and {} or hl_get(ns, { name = name, link = false })
  local data_ref = hl_get(ns, { name = name_ref, link = false })
  data = vim.tbl_deep_extend('keep', data, data_ref)

  for _, change in ipairs(changes) do
    for key, val in pairs(change) do
      if val == false then
        data[key] = nil
      elseif type(val) == 'function' then
        data[key] = val(data[key], data_ref[key], {
          key = key,
          name = name,
          name_ref = name_ref,
          ns = ns,
        })
      elseif data[val] ~= nil then
        data[key] = data[val]
      elseif data[val] ~= nil then
        data[key] = data_ref[val]
      else
        data[key] = val
      end
    end
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  hl_set(ns, name, data)
end

-- Provide a filtering function for highlight groups and attributes
local hl_filter_func = function(sch, names, attrs)
  names = (type(names) ~= 'table') and { names } or names
  attrs = (type(attrs) ~= 'table') and { attrs } or attrs

  return function(_, data)
    local matched_names = {}
    local match_name = (#names == 0)
    local match_attr = (#attrs == 0)
    if not match_name then
      for _, name in ipairs(names) do
        if data.name:find(name) then table.insert(matched_names, data.name) end
      end
      match_name = (#matched_names > 0)
    end
    if match_name and (not match_attr) then
      for _, attr in ipairs(attrs) do
        if data.attr == attr then
          match_attr = true
          break
        end
      end
    end
    local ok = match_name and match_attr
    if ok then
      for _, name in ipairs(matched_names) do
        sch._.links[name] = nil
      end
    end
    return ok
  end
end

-- Mix two colors together
local color_mix = function(val, ref)
  local a = MiniColors.convert(string.format('#%x', val), 'oklch')
  local b = MiniColors.convert(string.format('#%x', ref), 'oklch')
  return MiniColors.convert({
    l = (a.l + b.l) / 2,
    c = (a.c + b.c) / 2,
    h = (a.h + b.h) / 2,
  }, 'hex')
end

-- Modify a colorscheme's channel (eg. saturation, lightness... etc)
local sch_modify = function(sch, chan, val, names, attrs)
  local links = sch._.links
  local add = (type(val) == 'string') and (tonumber(val) ~= nil)
  local func = add and 'chan_add' or 'chan_set'
  local filter_func = hl_filter_func(sch, names, attrs)
  val = add and tonumber(val) or val
  local sch_new = sch[func](sch, chan, val, { filter = filter_func })
  sch_new._.links = links
  return sch_new
end

-- Save highlight groups links
local sch_links_save = function(sch)
  sch._ = sch._ or {}
  sch._.links = {}
  for name, val in pairs(sch.groups) do
    if val.link then
      sch._.links[name] = val.link
    end
  end
end

-- Restore highlight groups links
local sch_links_restore = function(sch)
  sch._ = sch._ or {}
  for name, link in pairs(sch._.links or {}) do
    if sch.groups[link] ~= nil then
      sch.groups[name] = { link = link }
    end
  end
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

  -- Tweak navigation highlighting
  hl_derive(0, 'MiniJump', 'Normal', {
    { bg = false }, { sp = 'fg' }, { bold = true }, { undercurl = true }
  })
  hl_set(0, 'FlashLabel', { link = 'MiniJump' })
  hl_derive(0, 'FlashMatch', 'palette.yellow', {
    { bg = false }, { fg = 'yellow' },
    { sp = 'fg' }, { bold = true }, { undercurl = true },
  })
  hl_derive(0, 'MiniPickMatchCurrent', 'MiniPickMatchCurrent', {
    { bold = true }, { undercurl = false },
  })
  hl_derive(0, 'MiniPickMatchRanges', 'palette.blue', {
    { bold = true }, { undercurl = true },
  })

  -- Tweak syntax highlighting
  hl_set(0, '@function', { link = 'palette.blue' })
  hl_derive(0, '@function', '@variable', { clear = false, { fg = color_mix } })
  hl_set(0, 'Function', { link = '@function' })
  hl_set(0, 'Directory', { link = '@function' })

  -- Get the colorscheme representation
  local sch = MiniColors.get_colorscheme(nil, { new_name = name })

  -- Record initial links before resolving them
  sch_links_save(sch)
  sch = sch:resolve_links()

  -- Tweak colorscheme content
  local exact = function(v) return '^' .. v .. '$' end
  sch = sch_modify(sch, 'saturation', '+15', nil, { 'fg', 'sp' })
  sch = sch_modify(sch, 'lightness', 95, exact('MiniJump'), { 'fg', 'sp' })
  sch = sch_modify(sch, 'saturation', 100, exact('FlashMatch'), { 'fg', 'sp' })

  -- Restore highlight groups links
  sch_links_restore(sch)

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
