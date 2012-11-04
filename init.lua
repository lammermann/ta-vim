-- Copyright 2012 Benjamin Kober k.o.b.e.r(att)web(dot)de. See LICENSE.
require 'textadept'
editing = require 'textadept.editing'

local M = {}

--[[ This comment is for LuaDoc.
---
-- Defines modes for keybindings like in vim.
--
-- It can be used this way:
-- 
-- vim = require 'vim'
-- keys = vim.use_vim_modes(keys)
--]]

function M.use_vim_modes(keys)
  local modes = {}
  
  modes._keys = {}
  modes._cur_mode = {}
  
  for key,val in pairs(keys) do
    modes._keys[key] = val
  end
  
  function modes.switch(self, mode)
    self._cur_mode = self[mode]
  end
  
  function modes.__index(self, key)
    val = modes._cur_mode[key]
    if val == nil then
      val = modes._keys[key]
    end
    return val
  end
  
  -- Global Keys
  -- window commands
  keys['cw'] = {
      s = { view.split, view },
      v = { view.split, view, true },
      c = { view.unsplit, view },
      ['\t']  = { gui.goto_view, 1, true },
      ['s\t'] = { gui.goto_view, -1, true },
      --o = utils.unsplit_all,
      --['='] = TODO
      --j = TODO
      --k = TODO
      --l = TODO
      --h = TODO
    }
  keys['cv'] = nil -- Workaround for visual block mode
  
  -- Normal Mode
  modes['normal'] = {
    -- other modes
    i  = { modes.switch, modes, 'insert'},
    R  = function()
      modes:switch('replace')
      buffer:edit_toggle_overtype()
    end,
    v  = { modes.switch, modes, 'visual'},
    cv = { modes.switch, modes, 'visual_block'},
    sv = { modes.switch, modes, 'visual_line'},
    -- undo / redo
    u  = buffer.undo,
    cr = buffer.redo,
    -- movement
    g  = {
      g = buffer.document_start,
      },
    G  = buffer.document_end,
    j  = buffer.line_down,
    k  = buffer.line_up,
    l  = buffer.char_right,
    h  = buffer.char_left,
    w  = buffer.word_right,
    b  = buffer.word_left,
    e  = buffer.word_right_end,
    ['$'] = buffer.line_end,
    }
  
  -- Insert Mode
  modes['insert'] = {
    ['esc'] = { modes.switch, modes, 'normal'}
    }
  
  -- Replace Mode
  modes['replace'] = {
    ['esc']  = function()
      modes:switch('normal')
      buffer:edit_toggle_overtype()
    end,
    }
  
  -- Visual Mode
  modes['visual'] = {
    ['esc'] = { modes.switch, modes, 'normal'},
    g  = {
      g = buffer.document_start_extend,
      },
    G  = buffer.document_end_extend,
    j  = buffer.line_down_extend,
    k  = buffer.line_up_extend,
    l  = buffer.char_right_extend,
    h  = buffer.char_left_extend,
    w  = buffer.word_right_extend,
    b  = buffer.word_left_extend,
    e  = buffer.word_right_end_extend,
    ['$'] = buffer.line_end_extend,
    }
  
  -- Visual Block Mode
  modes['visual_block'] = {
    ['esc'] = { modes.switch, modes, 'normal'},
    j  = buffer.line_down_rect_extend,
    k  = buffer.line_up_rect_extend,
    l  = buffer.char_right_rect_extend,
    h  = buffer.char_left_rect_extend,
    w  = buffer.word_right_rect_extend,
    b  = buffer.word_left_rect_extend,
    e  = buffer.word_right_end_rect_extend,
    ['$'] = buffer.line_end_rect_extend,
    }
  
  -- Visual Line Mode
  modes['visual_line'] = {
    ['esc'] = { modes.switch, modes, 'normal'},
    }
  
  -- initialize modul
  modes:switch('normal')
  setmetatable(keys, modes)
  M._modes = modes

  return keys
end

function M.bind_key(mode, key, fun, remove_old)
  remove_old = remove_old or false
  local mt = M._modes[mode] or {}
  if mt[key] == nil or remove_old then
    mt[key] = fun
  elseif type(mt[key]) == 'function' then
    local fn = mt[key]
    mt[key] = function()
      fun()
      fn()
    end
  elseif type(mt[key]) == 'table' then
    local t = mt[key]
    mt[key] = function()
      fun()
      -- t[0](t[1:]) TODO
    end
  end
end

return M
