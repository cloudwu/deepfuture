local mattext = require "soluna.material.text"
local matquad = require "soluna.material.quad"
local font = require "soluna.font"
local ui = require "core.rules".ui.editbox
local utf8 = utf8

global assert, print

local fontcobj = font.cobj()
local CURRENT_EDITBOX
local CURSOR_SPEED <const> = ui.cursor_speed
local CURSOR_COLOR <const> = ui.cursor_color
local KEY_LEFT <const> = 263
local KEY_RIGHT <const> = 262
local KEY_ESC <const> = 256
local KEY_ENTER <const> = 257
local KEY_DEL <const> = 261
local KEY_BACKSPACE <const> = 259
local KEY_HOME <const> = 268 
local KEY_END <const> = 269

local KEYSTATE_PRESS <const> = 1

local keyboard = {}

function keyboard.setup(callback)
	function callback.key(keycode, state)
		if state == KEYSTATE_PRESS then
			if CURRENT_EDITBOX then
				local cursor = CURRENT_EDITBOX.cursor
				if keycode == KEY_RIGHT then
					CURRENT_EDITBOX.cursor = cursor + 1
				elseif keycode == KEY_LEFT then
					CURRENT_EDITBOX.cursor = cursor - 1
				elseif keycode == KEY_HOME then
					CURRENT_EDITBOX.cursor = 0
				elseif keycode == KEY_END then
					local text = CURRENT_EDITBOX.text
					if text then
						CURRENT_EDITBOX.cursor = utf8.len(text)
					end
				elseif keycode == KEY_BACKSPACE then
					local input = CURRENT_EDITBOX.input
					if input then
						local offset = utf8.offset(input, -1) - 1
						if offset == 0 then
							CURRENT_EDITBOX.input = nil
						else
							input:sub(1, offset)
						end
					elseif cursor > 0 then
						local text = CURRENT_EDITBOX.text
						local offset_start, offset_end = utf8.offset(text, cursor)
						CURRENT_EDITBOX.cursor = cursor - 1
						CURRENT_EDITBOX.text = text:sub(1, offset_start - 1) .. text:sub(offset_end + 1)
						CURRENT_EDITBOX.label = nil
					end
				elseif keycode == KEY_DEL then
					local text = CURRENT_EDITBOX.text
					local offset_start, offset_end = utf8.offset(text, cursor+1)
					if offset_start then
						CURRENT_EDITBOX.text = text:sub(1, offset_start - 1) .. text:sub(offset_end + 1)
						CURRENT_EDITBOX.label = nil
					end
				elseif keycode == KEY_ESC then
					CURRENT_EDITBOX.exit = false
				elseif keycode == KEY_ENTER then
					CURRENT_EDITBOX.exit = true
				end
				CURRENT_EDITBOX.cursor_ticker = -CURSOR_SPEED
			end
		end
	end
	function callback.char(codepoint)
		if CURRENT_EDITBOX then
			local c = utf8.char(codepoint)
			CURRENT_EDITBOX.input = (CURRENT_EDITBOX.input or "") .. c
		end
	end
end

function keyboard.editbox(desc)
	CURRENT_EDITBOX = desc
	if desc then
		if not desc.block then
			desc.block, desc.cursor_get = mattext.block(
				fontcobj,
				assert(desc.fontid),
				assert(desc.fontsize),
				desc.color or 0,
				desc.align or "LV")
		end
		local text = desc.text or ""
		local width = desc.width
		local height = desc.height
		local cx, cy, cw, ch, cursor = desc.cursor_get(text, desc.cursor or utf8.len(text), width, height)
		if desc.input then
			local input_len = utf8.len(desc.input)
			local offset = utf8.offset(text, cursor + 1)
			text = text:sub(1, offset-1) .. desc.input .. text:sub(offset)
			desc.input = nil
			cursor = cursor + input_len
			cx, cy, cw, ch, cursor = desc.cursor_get(text, cursor, width, height)
			desc.label = nil
		end
		desc.cursor = cursor
		desc.text = text
		if not desc.label then
			desc.label = desc.block(text, width, height)
		end
		local cursor_ticker = desc.cursor_ticker or -CURSOR_SPEED
		cursor_ticker = cursor_ticker + 1
		if cursor_ticker <= 0 then
			-- show
			desc.cursor_quad = matquad.quad(cw, ch, CURSOR_COLOR)
			desc.cursor_x = cx
			desc.cursor_y = cy
		else
			-- hide
			desc.cursor_quad = nil
			if cursor_ticker > CURSOR_SPEED then
				cursor_ticker = -CURSOR_SPEED
			end
		end
		desc.cursor_ticker = cursor_ticker
		if desc.exit ~= nil then
			local r = desc.exit
			desc.exit = nil
			return r
		end
	end
end

return keyboard