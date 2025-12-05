-- /wopr/screen.lua
-- Screen helper: buffered printing, retype, blinking-cursor input

local screen = {}
local term = term
local os = os

screen.buffer = {}
local w,h = term.getSize()
screen.maxLines = h

-- trim the buffer so it fits terminal height
local function trimBuffer()
  while #screen.buffer > screen.maxLines do
    table.remove(screen.buffer, 1)
  end
end

-- re-render full buffer to screen
function screen.retype()
  term.clear()
  term.setCursorPos(1,1)
  for _,line in ipairs(screen.buffer) do
    print(line)
  end
end

-- push a single logical line (handles slow printing)
function screen.printSlow(text, delay)
  delay = delay or 0.03
  -- split on newlines
  for line in (text.."\n"):gmatch("(.-)\n") do
    table.insert(screen.buffer, line)
    trimBuffer()
    -- if buffer fills the screen we redraw whole buffer to avoid overwrites
    if #screen.buffer == screen.maxLines then
      screen.retype()
    else
      -- slowly print just this new line
      for c in line:gmatch(".") do
        write(c)
        sleep(delay)
      end
      print()
    end
  end
end

-- clear all screen buffer and terminal
function screen.reset()
  screen.buffer = {}
  term.clear()
  term.setCursorPos(1,1)
end

-- draw prompt line (always retype buffer for simplicity)
local function drawPrompt(prompt, input, cursorVisible)
  screen.retype()
  write(prompt .. input)
  if cursorVisible then write("_") else write(" ") end
end

-- Read line with blinking cursor. Supports characters and backspace.
-- Returns final input string.
function screen.input(prompt)
  prompt = prompt or "> "
  local input = ""
  local cursor = true
  drawPrompt(prompt, input, cursor)
  local blink = os.startTimer(0.5)

  while true do
    local ev, p1, p2 = os.pullEvent()
    if ev == "char" then
      -- typed character
      input = input .. p1
      drawPrompt(prompt, input, cursor)
    elseif ev == "key" then
      -- special keys
      if p1 == keys.backspace or p1 == 14 then
        if #input > 0 then input = input:sub(1, -2) end
        drawPrompt(prompt, input, cursor)
      elseif p1 == keys.enter then
        table.insert(screen.buffer, prompt .. input)
        trimBuffer()
        screen.retype()
        print()
        return input
      end
    elseif ev == "timer" and p1 == blink then
      cursor = not cursor
      drawPrompt(prompt, input, cursor)
      blink = os.startTimer(0.5)
    end
  end
end

-- convenience: print a line slowly then get input with blinking cursor
function screen.ask(prompt)
  screen.printSlow(prompt)
  return screen.input("> ")
end

-- optional: set green-on-black if available (harmless if not)
function screen.setGreenPhosphor(enable)
  local ok, colors = pcall(require, "colors")
  if not ok or not term.setTextColor then return end
  if enable then
    term.setTextColor(colors.green)
    term.setBackgroundColor(colors.black)
  else
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
  end
end

return screen
