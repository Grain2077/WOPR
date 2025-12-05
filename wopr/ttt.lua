-- /wopr/ttt.lua
-- Tic-Tac-Toe with simple learning; CC:Tweaked module
-- Exposes module.play()

local module = {}
local fs = fs
local textutils = textutils
local math = math

local DATA_FILE = "/wopr/ttt_experience.txt"
local memory = {}

local function ensureDataDir()
  if not fs.exists("/wopr") then fs.makeDir("/wopr") end
end

function module.load()
  ensureDataDir()
  if fs.exists(DATA_FILE) then
    local f = fs.open(DATA_FILE,"r")
    local d = textutils.unserialize(f.readAll())
    f.close()
    if type(d)=="table" then memory = d end
  end
end

function module.save()
  ensureDataDir()
  local f = fs.open(DATA_FILE,"w")
  f.write(textutils.serialize(memory))
  f.close()
end

local function boardKey(b) return table.concat(b) end

local function getEmpty(b)
  local ret = {}
  for i=1,9 do if b[i]==" " then table.insert(ret,i) end end
  return ret
end

local function checkWin(b)
  local lines = {{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}
  for _,ln in ipairs(lines) do
    local a,b1,c = b[ln[1]], b[ln[2]], b[ln[3]]
    if a~=" " and a==b1 and b1==c then return a end
  end
  for i=1,9 do if b[i]==" " then return nil end end
  return "draw"
end

local function recordMove(state, move, reward)
  memory[state] = memory[state] or {}
  memory[state][move] = (memory[state][move] or 0) + reward
end

local function chooseMove(b)
  local choices = getEmpty(b)
  local key = boardKey(b)
  if memory[key] then
    table.sort(choices, function(a,b2)
      local sa = memory[key][a] or 0
      local sb = memory[key][b2] or 0
      if sa == sb then return math.random() < 0.5 end
      return sa > sb
    end)
    if math.random() < 0.15 then return choices[math.random(#choices)] end
    return choices[1]
  else
    return choices[math.random(#choices)]
  end
end

function module.play()
  module.load()
  local board = {" "," "," "," "," "," "," "," "," "}
  local history = {}
  local turn = "X"
  while true do
    -- draw board
    print(string.format(" %s | %s | %s", board[1],board[2],board[3]))
    print("-----------")
    print(string.format(" %s | %s | %s", board[4],board[5],board[6]))
    print("-----------")
    print(string.format(" %s | %s | %s", board[7],board[8],board[9]))

    local winner = checkWin(board)
    if winner then
      for _,h in ipairs(history) do
        if winner == "draw" then recordMove(h.state,h.move,1)
        elseif h.mark == winner then recordMove(h.state,h.move,5)
        else recordMove(h.state,h.move,-2)
        end
      end
      module.save()
      if winner == "draw" then print("Game over: Draw.") else print("Game over: "..winner.." wins.") end
      return
    end

    if turn == "X" then
      local ok = false
      while not ok do
        write("Your move (1-9): ")
        local s = read()
        local n = tonumber(s)
        if n and n>=1 and n<=9 and board[n]==" " then
          board[n] = "X"
          table.insert(history, { state = boardKey(board), move = n, mark = "X" })
          ok = true
        else
          print("Invalid move.")
        end
      end
    else
      local pre = {}
      for i=1,9 do pre[i] = board[i] end
      local mv = chooseMove(board)
      board[mv] = "O"
      table.insert(history, { state = boardKey(pre), move = mv, mark = "O" })
      print("WOPR plays at "..mv.." (O)")
    end
    turn = (turn == "X") and "O" or "X"
  end
end

return module
