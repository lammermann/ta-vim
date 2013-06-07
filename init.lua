-- Copyright 2012 Benjamin Kober k.o.b.e.r(at)web(dot)de. See LICENSE.
require 'textadept'
editing = require 'textadept.editing'

-- dummy function replace key insertion
local function do_nothing()
  return -- don't do anything. Just prevent other actions
end

-- the modes modul
local M = {}

function M.mode_switch(mode)
  _G.keys.MODE = mode
  events.emit("VIM_SWITCH_MODE", mode)
end

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

  events.connect(events.UPDATE_UI, function()
    if keys.MODE == 'normal' then
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_BLOCK
    elseif keys.MODE == 'replace' then
      gui.statusbar_text = '-- REPLACE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual' then
      gui.statusbar_text = '-- VISUAL --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_block' then
      gui.statusbar_text = '-- VISUAL BLOCK --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_line' then
      gui.statusbar_text = '-- VISUAL LINE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    else
      gui.statusbar_text = '-- INSERT --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    end
  end)

  events.connect("VIM_SWITCH_MODE", function()
    if keys.MODE == 'normal' then
      gui.statusbar_text = ''
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_BLOCK
    elseif keys.MODE == 'replace' then
      gui.statusbar_text = '-- REPLACE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual' then
      gui.statusbar_text = '-- VISUAL --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_block' then
      gui.statusbar_text = '-- VISUAL BLOCK --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_line' then
      gui.statusbar_text = '-- VISUAL LINE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    else
      gui.statusbar_text = '-- INSERT --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    end
  end)

  -- {{{ helper functions

  M.multiply = ''

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
    keys[mode]['esc'] = function() M.multiply='' end
    for i = 0, 9 do
      number = tostring(i)
      keys[mode][number] = {append_multiply_buffer, number}
    end
  end

  -- }}}

  -- Global Keys
  keys['esc'] = function() keys.MODE = 'normal' end

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
  keys.normal = {
    -- other modes
    i  = M.mode_switch,
    I  = function()
      buffer.home()
      M.mode_switch()
    end,
    O  = function()
      buffer.line_up()
      buffer.line_end()
      buffer.new_line()
      M.mode_switch()
    end,
    o  = function()
      buffer.line_end()
      buffer.new_line()
      M.mode_switch()
    end,
    a  = function()
      buffer:char_right()
      M.mode_switch()
    end,
    A  = function()
      buffer.line_end()
      M.mode_switch()
    end,
    R  = function()
      buffer:edit_toggle_overtype()
      M.mode_switch("replace")
    end,
    v  = { M.mode_switch, "visual" },
    cv = { M.mode_switch, "visual_block" },
    V  = { M.mode_switch, "visual_line" },
    [':'] = gui.command_entry.focus,
    -- undo / redo
    u  = buffer.undo,
    cr = buffer.redo,
    -- movement
    g  = {
      g = buffer.document_start,
      },
    G  = function()
      if M.multiply == '' then
        buffer:document_end()
      else
        buffer:goto_line(tonumber(M.multiply) - 1)
        M.multiply = ''
      end
    end,
    j  = {multiply_action, buffer.line_down},
    k  = {multiply_action, buffer.line_up},
    l  = {multiply_action, buffer.char_right},
    h  = {multiply_action, buffer.char_left},
    w  = {multiply_action, buffer.word_right},
    b  = {multiply_action, buffer.word_left},
    e  = {multiply_action, buffer.word_right_end},
    ['$'] = buffer.line_end,
    --0 = buffer.home,
    -- cut, copy, paste
    d  = {
      d = buffer.line_cut,
      l = function()
        buffer:hide_selection(true)
        buffer.char_right_extend()
        buffer.cut()
        buffer:hide_selection(false)
      end,
      h = function()
        buffer:hide_selection(true)
        buffer.char_left_extend()
        buffer.cut()
        buffer:hide_selection(false)
      end,
      j = function()
        buffer:line_cut()
        buffer:line_cut()
      end,
      k = function()
        buffer:line_up()
        buffer:line_cut()
        buffer:line_cut()
      end,
    },
    -- folds
    z = {
      c = function()
        local line, num = buffer.get_cur_line()
        buffer:fold_children(num, _SCINTILLA.constants.SC_FOLDACTION_CONTRACT)
      end,
      o = function()
        local line, num = buffer.get_cur_line()
        buffer:fold_children(num, _SCINTILLA.constants.SC_FOLDACTION_EXPAND)
      end,
      }
    }
  add_multiply_bindings("normal")

  -- Visual Mode
  keys.visual = {
    ['esc'] = { M.mode_switch, "normal" },
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
    -- cut
    d = function()
      buffer.cut()
      M.mode_switch("normal")
    end,
  }

  -- Visual Block Mode
  keys.visual_block = {
    ['esc'] = { M.mode_switch, "normal" },
    j  = {multiply_action, buffer.line_down_rect_extend},
    k  = {multiply_action, buffer.line_up_rect_extend},
    l  = {multiply_action, buffer.char_right_rect_extend},
    h  = {multiply_action, buffer.char_left_rect_extend},
    w  = {multiply_action, buffer.word_right_rect_extend},
    b  = {multiply_action, buffer.word_left_rect_extend},
    e  = {multiply_action, buffer.word_right_end_rect_extend},
    ['$'] = buffer.line_end_rect_extend,
    -- cut
    d = function()
      buffer.cut()
      M.mode_switch("normal")
    end,
  }

  -- Visual Line Mode
  keys.visual_line = {
    ['esc'] = { M.mode_switch, "normal" },
  }

  -- Replace Mode
  keys.replace = {
    ['esc']  = function()
      M.mode_switch("normal")
      buffer:edit_toggle_overtype()
    end,
  }

  -- initialize modul
  M.mode_switch('normal') -- default mode

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
