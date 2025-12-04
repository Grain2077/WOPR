-- main.lua
-- WOPR for CC:Tweaked
-- Features:
--   Full-screen monitor dashboard
--   Advanced talk mode with ChatGPT + local fallback
--   Simplified Tic-Tac-Toe with basic learning
--   No DEFCON simulation
-- Save in /wopr/ folder on a CC:Tweaked computer

-- CONFIG
local MONITOR_SIDE = nil   -- nil = auto-find
local SPEAKER_SIDE = nil
local CHATGPT_BRIDGE_URL = "http://YOUR_PC_IP:5000/wopr" -- replace YOUR_PC_IP

-- IMPORTS
local fs = fs
local term = term
local textutils = textutils
local os = os
local math = math

-- GLOBALS
local monitor = nil
local speaker = nil
local dashboard = {mode="BOOT", uptime=0, experience=0, log={}}
local ttt_experience = {}
local TTT_DATA_FILE = "/wopr/ttt_experience.txt"

-- UTILITIES
local function findPeripherals()
  if MONITOR_SIDE and peripheral.isPresent(MONITOR_SIDE) and peripheral.getType(MONITOR_SIDE)=="monitor" then
    monitor = peripheral.wrap(MONITOR_SIDE)
  else
    local ok,m = pcall(peripheral.find,"monitor")
    if ok then monitor = m end
  end
  if SPEAKER_SIDE and peripheral.isPresent(SPEAKER_SIDE) and peripheral.getType(SPEAKER_SIDE)=="speaker" then
    speaker = peripheral.wrap(SPEAKER_SIDE)
  else
    local ok,s = pcall(peripheral.find,"speaker")
    if ok then speaker = s end
  end
end

local function dashboardLog(msg)
  table.insert(dashboard.log,1,msg)
  while #dashboard.log>10 do table.remove(dashboard.log) end
end

local function updateDashboard()
  if not monitor then return end
  monitor.setTextScale(0.5)
  monitor.clear()
  monitor.setCursorPos(1,1)
  monitor.write("=== WOPR SYSTEM STATUS ===\n\n")
  monitor.write("Mode:    "..dashboard.mode.."\n")
  monitor.write("Uptime:  "..string.format("%.1f sec",os.clock()-dashboard.uptime).."\n")
  monitor.write("TTT Exp: "..dashboard.experience.." states\n\n")
  monitor.write("Recent Events:\n")
  for i=1,math.min(10,#dashboard.log) do
    monitor.write("• "..dashboard.log[i].."\n")
  end
end

local function say(msg)
  print(msg)
  if monitor then
    local x,y = monitor.getCursorPos()
    local w,h = monitor.getSize()
    if y>=h then monitor.scroll(1); monitor.setCursorPos(1,h) end
    monitor.write(msg.."\n")
  end
end

-- TTT FUNCTIONS
local function ensureDataDir()
  if not fs.exists("/wopr") then fs.makeDir("/wopr") end
end

local function loadExperience()
  ensureDataDir()
  if fs.exists(TTT_DATA_FILE) then
    local f=fs.open(TTT_DATA_FILE,"r")
    local data=textutils.unserialize(f.readAll())
    f.close()
    if type(data)=="table" then ttt_experience=data end
  end
end

local function saveExperience()
  ensureDataDir()
  local f=fs.open(TTT_DATA_FILE,"w")
  f.write(textutils.serialize(ttt_experience))
  f.close()
end

local function boardToKey(board)
  return table.concat(board,"")
end

local function getEmptyIndexes(board)
  local ret={}
  for i=1,9 do if board[i]==" " then table.insert(ret,i) end end
  return ret
end

local function checkWin(board)
  local lines={{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}
  for _,l in ipairs(lines) do
    local a,b,c=board[l[1]],board[l[2]],board[l[3]]
    if a~=" " and a==b and b==c then return a end
  end
  for i=1,9 do if board[i]==" " then return nil end end
  return "draw"
end

local function ttt_record_move(board,move,reward)
  local key=boardToKey(board)
  ttt_experience[key]=ttt_experience[key] or {}
  ttt_experience[key][move]=(ttt_experience[key][move] or 0)+reward
end

local function ttt_choose_move(board)
  local choices=getEmptyIndexes(board)
  local key=boardToKey(board)
  if ttt_experience[key] then
    table.sort(choices,function(a,b)
      local sa=ttt_experience[key][a] or 0
      local sb=ttt_experience[key][b] or 0
      if sa==sb then return math.random()<0.5 end
      return sa>sb
    end)
    if math.random()<0.15 then return choices[math.random(#choices)] end
    return choices[1]
  else
    return choices[math.random(#choices)]
  end
end

local function playTTT()
  local board={}
  for i=1,9 do board[i]=" " end
  local history={}
  local turn="X"
  while true do
    local winner=checkWin(board)
    if winner then
      for _,h in ipairs(history) do
        if winner=="draw" then ttt_record_move(h.state,h.move,0.5)
        elseif h.mark==winner then ttt_record_move(h.state,h.move,3)
        else ttt_record_move(h.state,h.move,-1)
        end
      end
      saveExperience()
      dashboard.experience=0
      for _ in pairs(ttt_experience) do dashboard.experience=dashboard.experience+1 end
      updateDashboard()
      say("Game over: "..winner)
      return
    end

    if turn=="X" then
      say("Board:")
      local disp=""
      for r=0,2 do
        disp=disp..(" %s | %s | %s \n"):format(board[1+3*r],board[2+3*r],board[3+3*r])
        if r<2 then disp=disp.."-----------\n" end
      end
      say(disp)
      local choice=nil
      while true do
        write("Your move (1-9): ")
        choice=tonumber(read())
        if choice and board[choice]==" " then break else say("Invalid move.") end
      end
      board[choice]="X"
      table.insert(history,{state=boardToKey(board),move=choice,mark="X"})
    else
      local move=ttt_choose_move(board)
      local pre={}
      for i=1,9 do pre[i]=board[i] end
      board[move]="O"
      table.insert(history,{state=boardToKey(pre),move=move,mark="O"})
      say("WOPR plays at "..move.." (O)")
    end
    turn=(turn=="X") and "O" or "X"
  end
end

-- CHATGPT BRIDGE
local chatbridge={}
local ok,bridge=require,pcall
ok,bridge=pcall(require,"chatbridge")
if ok then chatbridge=bridge end

local function chatGPT(msg)
  if chatbridge and chatbridge.chat then
    local ok, resp=pcall(chatbridge.chat,msg)
    if ok and resp then return resp end
  end
  return nil
end

-- LOCAL TALK AI
local intent_keywords={
  play={"play","game","tic","toe","ttt"},
  greet={"hello","hi","hey"},
  who={"who","what","name"},
  status={"status","how","doing"},
  bye={"bye","exit","quit"},
  smalltalk={"bored","interesting","cool","talk"}
}

local responses={
  greet={"Greetings, Professor Falken.","Hello. Shall we play a game?"},
  who={"I am WOPR, a simulation computer.","I evaluate strategic scenarios."},
  status={function() return "Mode: "..dashboard.mode..", TTT entries: "..dashboard.experience end},
  smalltalk={"Interesting. Tell me more.","I am analyzing your statement."},
  bye={"Conversation terminated.","Returning to main menu."},
  play={"Starting Tic-Tac-Toe. You will be X."}
}

local function pickResponse(list)
  local r=list[math.random(#list)]
  if type(r)=="function" then return r() end
  return r
end

local function detectIntent(msg)
  msg=msg:lower()
  local best,bestScore=nil,0
  for intent,keys in pairs(intent_keywords) do
    local score=0
    for _,k in ipairs(keys) do if msg:find(k,1,true) then score=score+1 end end
    if score>bestScore then best,bestScore=intent,score end
  end
  if bestScore==0 then return "smalltalk" end
  return best
end

-- TALK MODE
function handleTalk()
  dashboard.mode="TALK"
  dashboardLog("Entered TALK mode")
  updateDashboard()
  say("WOPR: Conversation active. Type 'back' to exit.")
  while true do
    write("> ")
    local msg=read()
    if not msg then return end
    msg=msg:lower():gsub("%s+"," ")
    if msg=="back" then
      dashboard.mode="IDLE"
      dashboardLog("Exited TALK mode")
      updateDashboard()
      return
    end
    local reply=chatGPT(msg)
    if reply then
      say("WOPR: "..reply)
      dashboardLog("ChatGPT replied")
      updateDashboard()
    else
      local intent=detectIntent(msg)
      local resp=pickResponse(responses[intent] or responses.smalltalk)
      say("WOPR: "..resp)
      dashboardLog("Local AI replied (intent: "..intent..")")
      updateDashboard()
      if intent=="play" then playTTT() end
    end
  end
end

-- HELP
local function showHelp()
  say("WOPR commands:")
  say("  help     - show this help")
  say("  talk     - chat with WOPR")
  say("  play ttt - play Tic-Tac-Toe")
  say("  status   - show experience and dashboard info")
  say("  quit     - exit")
end

local function status()
  say(("TTT Experience entries: %d"):format(dashboard.experience))
end

-- BOOT
local function boot()
  math.randomseed(os.time()%65536)
  findPeripherals()
  loadExperience()
  dashboard.uptime=os.clock()
  dashboard.mode="BOOT"
  dashboardLog("System booted")
  updateDashboard()
  say("WOPR boot complete.")
  showHelp()
  while true do
    write("> ")
    local cmd=read()
    if not cmd then break end
    cmd=cmd:lower():gsub("^%s+",""):gsub("%s+$","")
    if cmd=="help" then showHelp()
    elseif cmd=="talk" then handleTalk()
    elseif cmd=="play ttt" then playTTT()
    elseif cmd=="status" then status()
    elseif cmd=="quit" or cmd=="exit" then say("Goodbye."); break
    else say("Unknown command. Type 'help'.")
    end
  end
end

-- RUN
boot()
