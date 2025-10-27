-- =============================================================================

-- Ensure 'mini' accessibility
local cwd = vim.fn.getcwd()
local mini_dir = cwd .. '/.deps/mini.nvim'
vim.opt.runtimepath:prepend(mini_dir)
local MiniHues = require('mini.hues')
local MiniColors = require('mini.colors')

-- =============================================================================

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

-- Create a colorscheme object from a given color palette
local scheme_create = function(palette)
  vim.cmd('highlight clear')
  MiniHues.apply_palette(palette)
  local scheme =  MiniColors.get_colorscheme(nil, {
    new_name = 'minihuit-' .. palette._.hue
  })
  scheme._ = { palette = palette }
  return scheme
end

-- =============================================================================

for _, hue in ipairs({ 180 }) do
  print(string.format("[generate.lua] Hue=%u", hue))

  local sch = scheme_create(palette_create(hue))
  sch:write({ directory = cwd .. '/colors' })
end
