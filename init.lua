-- Copyright 2012 Benjamin Kober k.o.b.e.r(at)web(dot)de. See LICENSE.
require 'textadept'
editing = require 'textadept.editing'

local P, R, Cs = lpeg.P, lpeg.R, lpeg.Cs

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
      ui.statusbar_text = ''
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_BLOCK
    elseif keys.MODE == 'replace' then
      ui.statusbar_text = '-- REPLACE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual' then
      ui.statusbar_text = '-- VISUAL --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_block' then
      ui.statusbar_text = '-- VISUAL BLOCK --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    elseif keys.MODE == 'visual_line' then
      ui.statusbar_text = '-- VISUAL LINE --'
      buffer.caret_style = _SCINTILLA.constants.CARETSTYLE_LINE
    else
      ui.statusbar_text = '-- INSERT --'
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

  local function unsplit_other(ts)
    if ts.vertical == nil then
      -- Ensure this view is focused (so we don't delete the focused view)
      for k,v in ipairs(_G._VIEWS) do
        if ts == v then
          ui.goto_view(k)
          break
        end
      end
      view.unsplit(ts)
    else
      unsplit_other(ts[1])
    end
  end
  
  local function close_view(v, ts)
    local v = view
    local ts = ts or ui.get_split_table()
  
    if ts.vertical == nil then
      -- This is just a view
      return false
    else
      if ts[1] == v then
        -- We can't quite just close the current view. Pick the first
        -- on the other side.
        return unsplit_other(ts[2])
      elseif ts[2] == v then
        return unsplit_other(ts[1])
      else
        return close_view(v, ts[1]) or close_view(v, ts[2])
      end
    end
  end

  local function move_to_view(v, direction, ts, left, right, above, under)
    local v = view
    local ts = ts or ui.get_split_table()
    local l = left  or v
    local r = right or v
    local a = above or v
    local u = under or v

    if ts.vertical == nil then
      -- This is just a view
      return false
    elseif ts.vertical == true then
      if ts[1] ~= v then l = ts[1] end
      if ts[2] ~= v then r = ts[2] end
    elseif ts.vertical == false then
      if ts[1] ~= v then a = ts[1] end
      if ts[2] ~= v then u = ts[2] end
    end

    if ts[1] == v or ts[2] == v then
      if direction == "right" then
        while r.vertical ~= nil do
          r = r[1]
        end
        return ui.goto_view(_G._VIEWS[r])
      elseif direction == "left" then
        while l.vertical ~= nil do
          l = l[2]
        end
        return ui.goto_view(_G._VIEWS[l])
      elseif direction == "above" then
        while a.vertical ~= nil do
          a = a[2]
        end
        return ui.goto_view(_G._VIEWS[a])
      elseif direction == "under" then
        while u.vertical ~= nil do
          u = u[1]
        end
        return ui.goto_view(_G._VIEWS[u])
      end
    else
      return move_to_view(v, direction, ts[1], l, r, a, u)
        or move_to_view(v, direction, ts[2], l, r, a, u)
    end
  end

  -- window commands
  keys['cw'] = {
      s = { view.split, view },
      v = { view.split, view, true },
      c = { close_view, view },
      ['\t']  = { ui.goto_view, 1, true },
      ['s\t'] = { ui.goto_view, -1, true },
      o = function() while view:unsplit() do end end,
      ['>'] = function() if view.size then view.size = view.size + 10 end end,
      ['<'] = function() if view.size then view.size = view.size - 10 end end,
      ['+'] = function() if view.size then view.size = view.size + 10 end end,
      ['-'] = function() if view.size then view.size = view.size - 10 end end,
      --['='] = TODO,
      j = { move_to_view, view, "under" },
      k = { move_to_view, view, "above" },
      l = { move_to_view, view, "right" },
      h = { move_to_view, view, "left" },
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
    [':'] = { ui.command_entry.enter_mode, "vim_command" },
    ['/'] = ui.find.find_incremental,
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
  cmd_pattern = P("q") / "quit()" 
    + P("w") / "save()"
    + Cs( P"" / ""
      )

  keys.vim_command = {
    ["\t"] = ui.command_entry.complete_lua, -- TODO vim complete
    ["\n"] = function()
      M.mode_switch("normal")
      if CURSES then keys.clear_key_sequence() end
      ui.command_entry.focus()
      local text = cmd_pattern:match(ui.command_entry.entry_text)
      ui.command_entry.execute_lua(text)
      if CURSES then return false end -- propagate to exit CDK entry on Enter
    end, -- TODO vim execution
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
