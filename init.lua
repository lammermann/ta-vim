-- Copyright 2012 Benjamin Kober k.o.b.e.r(at)web(dot)de. See LICENSE.
require 'textadept'
editing = require 'textadept.editing'

-- dummy function replace key insertion
local function do_nothing()
  return -- don't do anything. Just prevent other actions
end

-- the modes modul
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
  modes._cur = {}

  for key,val in pairs(keys) do
    modes._keys[key] = val
  end

  function modes.switch(self, mode)
    self._cur = self[mode]
    buffer.caret_style =
      self._cur.caret_style or _SCINTILLA.constants.CARETSTYLE_LINE
  end

  function modes.__index(self, key)
    val = modes._cur.keys[key]
    if val == nil then
      val = modes._keys[key]
    end
    if val == nil and modes._cur.ignore_defaults then
      return do_nothing
    end
    return val
  end

  M.multiply = ''

  -- {{{ helper functions

  -- perform `action` for `M.multiply` times
  local function multiply_action(action, ...)
    local n = tonumber(M.multiply) or 1
    M.multiply = ''
    while n > 0 do
      action(...)
      n = n-1
    end
  end

  local function append_multiply_buffer(number)
    M.multiply = M.multiply .. number
  end

  local function add_multiply_bindings(mode)
    modes[mode].keys['esc'] = function() M.multiply='' end
    for i = 0, 9 do
      number = tostring(i)
      modes[mode].keys[number] = {append_multiply_buffer, number}
    end
  end

  -- }}}

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
    ignore_defaults = true,
    caret_style = _SCINTILLA.constants.CARETSTYLE_BLOCK,
    keys = {
      -- other modes
      i  = { modes.switch, modes, 'insert'},
      I  = function()
        buffer.home()
        modes:switch('insert')
      end,
      O  = function()
        buffer.line_up()
        buffer.line_end()
        buffer.new_line()
        modes:switch('insert')
      end,
      o  = function()
        buffer.line_end()
        buffer.new_line()
        modes:switch('insert')
      end,
      A  = function()
        buffer.line_end()
        modes:switch('insert')
      end,
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
      j  = {multiply_action, buffer.line_down},
      k  = {multiply_action, buffer.line_up},
      l  = {multiply_action, buffer.char_right},
      h  = {multiply_action, buffer.char_left},
      w  = {multiply_action, buffer.word_right},
      b  = {multiply_action, buffer.word_left},
      e  = {multiply_action, buffer.word_right_end},
      ['$'] = buffer.line_end,
      --0 = buffer.home,
      }
  }
  add_multiply_bindings("normal")

  -- Insert Mode
  modes['insert'] = {
    keys = {
      ['esc'] = { modes.switch, modes, 'normal'}
    }
  }

  -- Replace Mode
  modes['replace'] = {
    keys = {
      ['esc']  = function()
        modes:switch('normal')
        buffer:edit_toggle_overtype()
    end,
    }
  }

  -- Visual Mode
  modes['visual'] = {
    ignore_defaults = true,
    keys = {
      ['esc'] = { modes.switch, modes, 'normal'},
      g  = {
        g = buffer.document_start_extend,
        },
      G  = buffer.document_end_extend,
      j  = {multiply_action, buffer.line_down_extend},
      k  = {multiply_action, buffer.line_up_extend},
      l  = {multiply_action, buffer.char_right_extend},
      h  = {multiply_action, buffer.char_left_extend},
      w  = {multiply_action, buffer.word_right_extend},
      b  = {multiply_action, buffer.word_left_extend},
      e  = {multiply_action, buffer.word_right_end_extend},
      ['$'] = buffer.line_end_extend,
    }
  }

  -- Visual Block Mode
  modes['visual_block'] = {
    ignore_defaults = true,
    keys = {
      ['esc'] = { modes.switch, modes, 'normal'},
      j  = {multiply_action, buffer.line_down_rect_extend},
      k  = {multiply_action, buffer.line_up_rect_extend},
      l  = {multiply_action, buffer.char_right_rect_extend},
      h  = {multiply_action, buffer.char_left_rect_extend},
      w  = {multiply_action, buffer.word_right_rect_extend},
      b  = {multiply_action, buffer.word_left_rect_extend},
      e  = {multiply_action, buffer.word_right_end_rect_extend},
      ['$'] = buffer.line_end_rect_extend,
    }
  }

  -- Visual Line Mode
  modes['visual_line'] = {
    ignore_defaults = true,
    keys = {
      ['esc'] = { modes.switch, modes, 'normal'},
    }
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
    for k,v in pairs(t) do
      M.bind_key(mode, key, v, false)
    end
  end
end

return M
