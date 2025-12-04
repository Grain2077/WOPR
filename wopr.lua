-- WOPR-like AI for CC:Tweaked
-- Save as /wopr/main.lua and run on a CC:Tweaked computer.
-- Author: assistant (example)
-- Features:
--  - Console + optional monitor output
--  - Tic-Tac-Toe with simple reinforcement learning (stored on disk)
--  - Simple conversational interface and simulation mode

local fs = fs
local textutils = textutils
local term = term
local os = os
local math = math

-- CONFIG
local DATA_DIR = "/wopr"
local TTT_DATA_FILE = DATA_DIR .. "/ttt_experience.txt"
local MONITOR_SIDE = nil   -- set to "top" or "left" to prefer a side; nil -> auto-find
local SPEAKER_SIDE = nil

-- Utilities: peripherals
local monitor = nil
local speaker = nil
local function find_peripherals()
  if MONITOR_SIDE then
    if peripheral.isPresent(MONITOR_SIDE) and peripheral.getType(MONITOR_SIDE) == "monitor" then
      monitor = peripheral.wrap(MONITOR_SIDE)
    end
  else
    local ok, m = pcall(peripheral.find, "monitor")
    if ok then monitor = m end
  end

  if SPEAKER_SIDE then
    if peripheral.isPresent(SPEAKER_SIDE) and peripheral.getType(SPEAKER_SIDE) == "speaker" then
      speaker = peripheral.wrap(SPEAKER_SIDE)
    end
  else
    local ok, s = pcall(peripheral.find, "speaker")
    if ok then speaker = s end
  end
end

-- Simple output helpers
local function writeMonitorLine(text, line)
  if not monitor then return false end
  local w,h = monitor.getSize()
  monitor.setCursorPos(1, line or 1)
  monitor.clearLine()
  monitor.write(text)
  return true
end

local function say(text)
  -- prints to terminal and monitor (if present). Also plays a sound if speaker present.
  print(text)
  if monitor then
    -- append to monitor: find first empty line or scroll
    -- naive: find current cursor and write
    local w,h = monitor.getSize()
    local x,y = monitor.getCursorPos()
    if y >= h then monitor.scroll(1); monitor.setCursorPos(1,h) end
    monitor.write(text .. "\n")
  end
  if speaker and speaker.playSound then
    -- speaker API may vary; try safe calls
    pcall(function() speaker.playSound("minecraft:entity.villager.trading", 1, 1) end)
  end
end

-- DATA IO for TTT (learning)
local ttt_experience = {}  -- maps boardState -> {moveIndex -> score}
local function ensureDataDir()
  if not fs.exists(DATA_DIR) then
    fs.makeDir(DATA_DIR)
  end
end

local function loadExperience()
  ensureDataDir()
  if fs.exists(TTT_DATA_FILE) then
    local f = fs.open(TTT_DATA_FILE, "r")
    local txt = f.readAll()
    f.close()
    if txt and #txt > 0 then
      local ok, data = pcall(textutils.unserialize, txt)
      if ok and type(data) == "table" then
        ttt_experience = data
      end
    end
  end
end

local function saveExperience()
  ensureDataDir()
  local f = fs.open(TTT_DATA_FILE, "w")
  f.write(textutils.serialize(ttt_experience))
  f.close()
end

-- TTT helpers
local function boardToKey(board)
  -- board is array 1..9 with "X","O" or " "
  return table.concat(board, "")
end

local function getEmptyIndexes(board)
  local ret = {}
  for i=1,9 do if board[i] == " " then table.insert(ret,i) end end
  return ret
end

local function checkWin(board)
  local lines = {
    {1,2,3},{4,5,6},{7,8,9},
    {1,4,7},{2,5,8},{3,6,9},
    {1,5,9},{3,5,7}
  }
  for _,ln in ipairs(lines) do
    local a,b,c = board[ln[1]], board[ln[2]], board[ln[3]]
    if a ~= " " and a == b and b == c then
      return a -- "X" or "O"
    end
  end
  for i=1,9 do if board[i] == " " then return nil end end
  return "draw"
end

-- Simple RL: each boardState maps to table of move->score
local function ttt_record_move(board, move, reward)
  local key = boardToKey(board)
  ttt_experience[key] = ttt_experience[key] or {}
  ttt_experience[key][move] = (ttt_experience[key][move] or 0) + reward
end

local function ttt_choose_move(board, myMark)
  local key = boardToKey(board)
  local choices = getEmptyIndexes(board)
  if ttt_experience[key] then
    -- rank moves by score; prefer higher
    table.sort(choices, function(a,b)
      local sa = ttt_experience[key][a] or 0
      local sb = ttt_experience[key][b] or 0
      if sa == sb then return math.random() < 0.5 end
      return sa > sb
    end)
    -- add small exploration chance
    if math.random() < 0.15 then
      return choices[math.random(#choices)]
    end
    return choices[1]
  else
    -- no data: try best heuristics (center, corners)
    local heur = {5,1,3,7,9,2,4,6,8}
    for _,c in ipairs(heur) do
      for _,e in ipairs(choices) do if e==c then return c end end
    end
    return choices[math.random(#choices)]
  end
end

-- Play a TTT game: human vs AI or AI vs AI
-- returns winner: "X","O","draw"
local function playTTT(opts)
  opts = opts or {}
  local humanMark = opts.humanMark or "X" -- if nil, AI vs AI
  local aiMark = (humanMark == "X") and "O" or "X"
  local board = {}
  for i=1,9 do board[i] = " " end
  local history = {} -- list of {state,move,mark}
  local turn = "X"
  while true do
    local winner = checkWin(board)
    if winner then
      -- reward history
      for _,entry in ipairs(history) do
        -- simple reward: +3 for winner moves, -1 for loser moves, 0 for draws
        if winner == "draw" then
          ttt_record_move(entry.state, entry.move, 0.5)
        else
          if entry.mark == winner then
            ttt_record_move(entry.state, entry.move, 3)
          else
            ttt_record_move(entry.state, entry.move, -1)
          end
        end
      end
      saveExperience()
      return winner
    end

    if humanMark and turn == humanMark then
      -- prompt human
      say("Board:")
      local display = ""
      for r=0,2 do
        display = display .. (" %s | %s | %s \n"):format(board[1+3*r], board[2+3*r], board[3+3*r])
        if r < 2 then display = display .. "-----------\n" end
      end
      say(display)
      local valid = false
      local choice = nil
      while not valid do
        write("Your move (1-9): ")
        local s = read()
        choice = tonumber(s)
        if choice and board[choice] == " " and choice >=1 and choice <=9 then
          valid = true
        else
          say("Invalid move.")
        end
      end
      board[choice] = humanMark
      table.insert(history, {state = boardToKey(board), move = choice, mark = humanMark})
    else
      -- AI move
      local move = ttt_choose_move(board, turn)
      -- record pre-move state (so later we reward based on result)
      local pre = {}
      for i=1,9 do pre[i]=board[i] end
      board[move] = turn
      table.insert(history, {state = boardToKey(pre), move = move, mark = turn})
      say("WOPR plays at " .. tostring(move) .. " (" .. turn .. ")")
      os.sleep(0.3)
    end

    turn = (turn == "X") and "O" or "X"
  end
end

-- Conversation (very simple)
local canned = {
  hello = "Greetings, Professor Falken.",
  who = "I am a simulation. Would you like to play a game?",
  war = "Shall we play WarGames? I can simulate scenarios.",
  ttt = "I can play Tic-Tac-Toe. Type 'play ttt' to start.",
  bye = "Shutting down conversational module."
}

local function handleTalk()
  say("WOPR: You can ask simple things. Type 'back' to return.")
  while true do
    write("> ")
    local s = read()
    if not s then return end
    s = s:lower():gsub("%s+"," ")
    if s == "back" or s == "exit" then return end
    if s:match("play") and s:match("tic") then
      say("Starting Tic-Tac-Toe. You will be 'X'.")
      playTTT({humanMark="X"})
    else
      local resp = canned[s] or "Interesting. Tell me more."
      say("WOPR: " .. resp)
    end
  end
end

-- Simulation mode: harmless theatrics
local function simulate()
  say("Initializing DEFCON simulation...")
  for i=5,1,-1 do
    say("DEFCON " .. i)
    os.sleep(0.5)
  end
  say("Scanning global threat matrices...")
  os.sleep(1)
  local scenarios = {
    "Nuclear arms escalation - probability 0.0001",
    "Diplomatic resolution - probability 0.78",
    "Unintended launch (simulated) - probability 0.00001",
    "Cyber interference - probability 0.05"
  }
  for _,sc in ipairs(scenarios) do
    say(sc)
    os.sleep(0.7)
  end
  say("Running learning loop (simulated).")
  -- run some AI vs AI TTT games to demonstrate learning
  say("Demonstration: AI learning by self-play (tic-tac-toe).")
  local wins = {X=0,O=0,draw=0}
  for i=1,30 do
    local w = playTTT({humanMark=nil})
    wins[w] = wins[w] + 1
  end
  say(("Self-play complete: X=%d O=%d draw=%d"):format(wins.X, wins.O, wins.draw))
  say("Simulation complete.")
end

-- UI / main
local function showHelp()
  say("WOPR commands:")
  say("  help        - show this help")
  say("  talk        - chat with WOPR")
  say("  play ttt    - play Tic-Tac-Toe vs WOPR")
  say("  simulate    - run a harmless 'DEFCON' simulation and watch learning")
  say("  status      - show learned states count")
  say("  quit        - exit")
end

local function status()
  local n = 0
  for k,v in pairs(ttt_experience) do n = n + 1 end
  say(("Experience entries: %d"):format(n))
end

-- Boot
local function boot()
  math.randomseed(os.time() % 65536)
  find_peripherals()
  loadExperience()
  say("WOPR (CC:Tweaked) booting.")
  if monitor then
    monitor.clear()
    monitor.setCursorPos(1,1)
    monitor.write("WOPR ONLINE\n")
  end
  showHelp()
  while true do
    write("> ")
    local cmd = read()
    if not cmd then break end
    cmd = cmd:lower():gsub("^%s+",""):gsub("%s+$","")
    if cmd == "help" then showHelp()
    elseif cmd == "talk" then handleTalk()
    elseif cmd == "play ttt" or cmd == "play tictactoe" then
      say("You are X (first).")
      playTTT({humanMark="X"})
    elseif cmd == "simulate" then simulate()
    elseif cmd == "status" then status()
    elseif cmd == "quit" or cmd == "exit" then
      say("Goodbye.")
      break
    elseif cmd == "" then -- ignore
    else
      say("Unknown command. Type 'help'.")
    end
  end
end

-- Run
boot()
