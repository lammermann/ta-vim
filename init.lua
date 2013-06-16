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

  local function on_update_ui()
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
  end

  events.connect(events.UPDATE_UI, on_update_ui)
  events.connect("VIM_SWITCH_MODE", function()
    if keys.MODE == 'visual' then
      buffer.selection_mode = _SCINTILLA.constants.SC_SEL_STREAM
    elseif keys.MODE == 'visual_line' then
      buffer.selection_mode = _SCINTILLA.constants.SC_SEL_LINES
    else
      local pos = buffer.current_pos
      buffer:cancel()
      buffer:goto_pos(pos)
    end
    on_update_ui()
  end)

  -- {{{ Global Keys
  -- have to be set before the _ignore_defaults table
  keys['esc'] = { M.mode_switch, "normal" }

  local function table2str(t)
    local out = "{ \n"
    for k,v in pairs(t) do
      out = out .. tostring(k) .. " = "
      if type(v) == "table" then
        out = out .. table2str(v)
      else
        out = out .. tostring(v)
      end
      out = out .. ",\n"
    end
    out = out .. "}\n"
    return out
  end

  -- window commands
  keys['cw'] = {
      s = { view.split, view },
      v = { view.split, view, true },
      c = { view.unsplit, view },
      ['\t']  = { gui.goto_view, 1, true },
      ['s\t'] = { gui.goto_view, -1, true },
      t = function()
        print(table2str(gui.get_split_table()))
      end,
      o = function() while view:unsplit() do end end,
      ['>'] = function() if view.size then view.size = view.size + 10 end end,
      ['<'] = function() if view.size then view.size = view.size - 10 end end,
      ['+'] = function() if view.size then view.size = view.size + 10 end end,
      ['-'] = function() if view.size then view.size = view.size - 10 end end,
      --['='] = TODO
      --j = TODO
      --k = TODO
      --l = TODO
      --h = TODO
  }
  keys['cv'] = nil -- Workaround for visual block mode

  -- }}}

  -- {{{ helper functions

  -- add multiply bindings
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

  -- ignore default keys
  M._ignore_defaults = {
    down  = { multiply_action, buffer.line_down },
    up    = { multiply_action, buffer.line_up },
    left  = { multiply_action, buffer.char_left },
    right = { multiply_action, buffer.char_right },
    ['end'] = { multiply_action, buffer.line_end },
  }

  for key,val in pairs(keys) do
    M._ignore_defaults[key] = val
  end

  M._ignore_defaults.__index = function(self, key)
    val = M._ignore_defaults[key]
    if val == nil then
      return do_nothing
    end
    return val
  end

  -- }}}

  -- movement commands
  M._movements = {
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
    ['%'] = editing.match_brace,
    ['$'] = buffer.line_end,
    ['0']  = function()
      if M.multiply == '' then
        return buffer:home()
      end
      append_multiply_buffer('0')
    end,
    ['esc'] = function() M.multiply = '' end,
  }
  for i = 1, 9 do
    number = tostring(i)
    M._movements[number] = {append_multiply_buffer, number}
  end
  M._movements.__index = M._movements

  setmetatable(M._movements, M._ignore_defaults)

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
    [':'] = { gui.command_entry.enter_mode, "vim_command" },
    -- modify content
    ['~'] = { multiply_action, function()
      buffer:set_selection(buffer.current_pos, buffer.current_pos+1)
      local c = buffer.get_sel_text()
      local newc = string.upper(c)
      if newc == c then newc = string.lower(c) end
      buffer.replace_sel(newc)
    end },
    -- undo / redo
    u  = buffer.undo,
    cr = buffer.redo,
    -- cut, copy, paste
    x  = function()
      buffer:hide_selection(true)
      buffer.char_right_extend()
      buffer.cut()
      buffer:hide_selection(false)
    end,
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
    y  = {
      y = buffer.line_copy,
      l = function()
        buffer:hide_selection(true)
        buffer.char_right_extend()
        buffer:copy()
        buffer:hide_selection(false)
      end,
      h = function()
        buffer:hide_selection(true)
        buffer.char_left_extend()
        buffer.copy()
        buffer:hide_selection(false)
      end,
    },
    p = {
      p = buffer.paste,
      P = function()
        buffer:line_up()
        buffer:paste()
        buffer:line_down()
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
  setmetatable(keys.normal, M._movements)

  -- vim command entry
  keys.vim_command = {
    ["\t"] = gui.command_entry.complete_lua, -- TODO vim complete
    ["\n"] = { gui.command_entry.finish_mode,
      gui.command_entry.execute_lua }, -- TODO vim execution
  }

  -- Visual Mode
  keys.visual = {
    ['esc'] = { M.mode_switch, "normal" },
    -- cut, copy, paste
    d = function()
      buffer.cut()
      M.mode_switch("normal")
    end,
    y = function()
      buffer.copy()
      M.mode_switch("normal")
    end,
    p = function()
      buffer.paste()
      M.mode_switch("normal")
    end,
  }
  setmetatable(keys.visual, M._movements)

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
    -- cut, copy, paste
    d = function()
      buffer.cut()
      M.mode_switch("normal")
    end,
    y = function()
      buffer.copy()
      M.mode_switch("normal")
    end,
    p = function()
      buffer.paste()
      M.mode_switch("normal")
    end,
  }
  setmetatable(keys.visual_block, M._movements)

  -- Visual Line Mode
  keys.visual_line = {
    ['esc'] = { M.mode_switch, "normal" },
  }
  setmetatable(keys.visual_line, M._movements)

  -- Replace Mode
  keys.replace = {
    ['esc']  = function()
      M.mode_switch("normal")
      buffer:edit_toggle_overtype()
    end,
    -- cut, copy, paste
    d = function()
      buffer.cut()
      M.mode_switch("normal")
    end,
    y = function()
      buffer.copy()
      M.mode_switch("normal")
    end,
    p = function()
      buffer.paste()
      M.mode_switch("normal")
    end,
  }

  -- initialize modul
  M.mode_switch('normal') -- default mode

  return keys

end

return M
