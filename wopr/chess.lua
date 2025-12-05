-- /wopr/chess.lua
-- /wopr/chess.lua
local fs = fs
local textutils = textutils
local math = math
local os = os

local chess = {}
local DATA_FILE = "/wopr/chess_experience.txt"
local experience = {}

-- set search depth to 2 (fast)
chess.SEARCH_DEPTH = 2

-- piece values (centipawns)
local pieceValue = { p=100, n=320, b=330, r=500, q=900, k=20000 }

-- Ensure data directory
local function ensureDataDir()
  if not fs.exists("/wopr") then fs.makeDir("/wopr") end
end

function chess.loadExperience()
  ensureDataDir()
  if fs.exists(DATA_FILE) then
    local f = fs.open(DATA_FILE, "r")
    local d = textutils.unserialize(f.readAll())
    f.close()
    if type(d) == "table" then experience = d end
  end
end

function chess.saveExperience()
  ensureDataDir()
  local f = fs.open(DATA_FILE, "w")
  f.write(textutils.serialize(experience))
  f.close()
end

-- Board representation: board[row][col] 1..8
function chess.newBoard()
  local init = {
    {"r","n","b","q","k","b","n","r"},
    {"p","p","p","p","p","p","p","p"},
    {".",".",".",".",".",".",".","."},
    {".",".",".",".",".",".",".","."},
    {".",".",".",".",".",".",".","."},
    {".",".",".",".",".",".",".","."},
    {"P","P","P","P","P","P","P","P"},
    {"R","N","B","Q","K","B","N","R"},
  }
  local b = {}
  for r=1,8 do
    b[r] = {}
    for c=1,8 do b[r][c] = init[r][c] end
  end
  return b
end

-- helpers
local function inside(r,c) return r>=1 and r<=8 and c>=1 and c<=8 end
local function isWhite(p) if p=="." then return nil end return p:match("%u") ~= nil end

-- generate pseudo-legal moves (does NOT check for checks for speed)
local function genMoves(board, white)
  local moves = {}
  local knightDirs = {{2,1},{2,-1},{-2,1},{-2,-1},{1,2},{-1,2},{1,-2},{-1,-2}}
  local kingDirs = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
  local straightDirs = {{1,0},{-1,0},{0,1},{0,-1}}
  local diagDirs = {{1,1},{1,-1},{-1,1},{-1,-1}}
  for r=1,8 do for c=1,8 do
    local p = board[r][c]
    if p ~= "." then
      local pWhite = isWhite(p)
      if pWhite == white then
        local pl = p:lower()
        if pl == "p" then
          local dir = white and -1 or 1
          local r1 = r + dir
          if inside(r1,c) and board[r1][c] == "." then
            table.insert(moves,{fromR=r,fromC=c,toR=r1,toC=c,promote=(r1==1 or r1==8)})
            local startRank = white and 7 or 2
            local r2 = r + 2*dir
            if r == startRank and board[r2][c] == "." then
              table.insert(moves,{fromR=r,fromC=c,toR=r2,toC=c})
            end
          end
          for _,dc in ipairs({-1,1}) do
            local rr,cc = r+dir, c+dc
            if inside(rr,cc) then
              local t = board[rr][cc]
              if t ~= "." and isWhite(t) ~= pWhite then
                table.insert(moves,{fromR=r,fromC=c,toR=rr,toC=cc,promote=(rr==1 or rr==8)})
              end
            end
          end

        elseif pl == "n" then
          for _,d in ipairs(knightDirs) do
            local rr,cc = r+d[1], c+d[2]
            if inside(rr,cc) then
              local t = board[rr][cc]
              if t == "." or isWhite(t) ~= pWhite then table.insert(moves,{fromR=r,fromC=c,toR=rr,toC=cc}) end
            end
          end

        elseif pl == "b" or pl == "r" or pl == "q" then
          local dirs = (pl=="b") and diagDirs or (pl=="r") and straightDirs or (function()
            local all = {}
            for _,v in ipairs(straightDirs) do table.insert(all,v) end
            for _,v in ipairs(diagDirs) do table.insert(all,v) end
            return all
          end)()
          for _,d in ipairs(dirs) do
            local rr,cc = r+d[1], c+d[2]
            while inside(rr,cc) do
              local t = board[rr][cc]
              if t == "." then
                table.insert(moves,{fromR=r,fromC=c,toR=rr,toC=cc})
              else
                if isWhite(t) ~= pWhite then table.insert(moves,{fromR=r,fromC=c,toR=rr,toC=cc}) end
                break
              end
              rr = rr + d[1]; cc = cc + d[2]
            end
          end

        elseif pl == "k" then
          for _,d in ipairs(kingDirs) do
            local rr,cc = r+d[1], c+d[2]
            if inside(rr,cc) then
              local t = board[rr][cc]
              if t == "." or isWhite(t) ~= pWhite then table.insert(moves,{fromR=r,fromC=c,toR=rr,toC=cc}) end
            end
          end
        end
      end
    end
  end end
  return moves
end

local function applyMove(board, mv)
  local nb = {}
  for r=1,8 do nb[r] = {}; for c=1,8 do nb[r][c] = board[r][c] end end
  local piece = nb[mv.fromR][mv.fromC]
  nb[mv.toR][mv.toC] = piece
  nb[mv.fromR][mv.fromC] = "."
  if mv.promote then
    nb[mv.toR][mv.toC] = piece:match("%u") and "Q" or "q"
  end
  return nb
end

local function boardKey(board)
  local s = {}
  for r=1,8 do for c=1,8 do s[#s+1] = board[r][c] end end
  return table.concat(s)
end

local function moveKey(mv) return string.format("%d%d_%d%d", mv.fromR, mv.fromC, mv.toR, mv.toC) end

-- evaluation: material + mobility + center bonus
local function evaluate(board)
  local score = 0
  for r=1,8 do for c=1,8 do
    local p = board[r][c]
    if p ~= "." then
      local sign = p:match("%u") and 1 or -1
      local v = pieceValue[p:lower()] or 0
      score = score + sign * v
      if r>=3 and r<=6 and c>=3 and c<=6 then score = score + sign*10 end
    end
  end end
  local mw = #genMoves(board, true)
  local mb = #genMoves(board, false)
  score = score + (mw - mb) * 5
  return score
end

-- experience bias for moves in this position
local function experienceBias(board, moves)
  local key = boardKey(board)
  local tableForKey = experience[key] or {}
  local biases = {}
  for _,mv in ipairs(moves) do biases[moveKey(mv)] = tableForKey[moveKey(mv)] or 0 end
  return biases
end

-- minimax with alpha-beta (returns score, bestMove)
local function minimax(board, depth, alpha, beta, maximizing)
  if depth == 0 then return evaluate(board), nil end
  local moves = genMoves(board, maximizing)
  if #moves == 0 then return evaluate(board), nil end
  local biases = experienceBias(board, moves)

  if maximizing then
    local bestScore = -1e9
    local bestMv = nil
    for _,mv in ipairs(moves) do
      local child = applyMove(board, mv)
      local sc,_ = minimax(child, depth-1, alpha, beta, false)
      sc = sc + (biases[moveKey(mv)] or 0)
      if sc > bestScore then bestScore = sc; bestMv = mv end
      alpha = math.max(alpha, bestScore)
      if alpha >= beta then break end
    end
    return bestScore, bestMv
  else
    local bestScore = 1e9
    local bestMv = nil
    for _,mv in ipairs(moves) do
      local child = applyMove(board, mv)
      local sc,_ = minimax(child, depth-1, alpha, beta, true)
      sc = sc - (biases[moveKey(mv)] or 0)
      if sc < bestScore then bestScore = sc; bestMv = mv end
      beta = math.min(beta, bestScore)
      if alpha >= beta then break end
    end
    return bestScore, bestMv
  end
end

local function chooseMove(board, isWhite)
  chess.loadExperience()
  local _, mv = minimax(board, chess.SEARCH_DEPTH, -1e9, 1e9, not not isWhite)
  if not mv then
    local moves = genMoves(board, isWhite)
    if #moves == 0 then return nil end
    return moves[math.random(#moves)]
  end
  if math.random() < 0.12 then
    local m = genMoves(board, isWhite)
    return m[math.random(#m)]
  end
  return mv
end

local function checkGameEnd(board)
  local wK, bK = false, false
  for r=1,8 do for c=1,8 do
    if board[r][c] == "K" then wK = true end
    if board[r][c] == "k" then bK = true end
  end end
  if not wK then return "black" end
  if not bK then return "white" end
  return nil
end

local function recordHistory(history, winner)
  for _,entry in ipairs(history) do
    local bkey = entry.boardKey
    experience[bkey] = experience[bkey] or {}
    local mk = moveKey(entry.move)
    local reward = 0
    if winner == "draw" then reward = 2
    else
      local didWin = (winner == "white" and entry.white) or (winner == "black" and not entry.white)
      reward = didWin and 8 or -2
    end
    experience[bkey][mk] = (experience[bkey][mk] or 0) + reward
  end
  chess.saveExperience()
end

-- pretty helper
function chess._pretty(board)
  local out = {}
  for r=1,8 do
    local row = ""
    for c=1,8 do row = row .. board[r][c] .. " " end
    out[#out+1] = row
  end
  return out
end

-- play: human is white
function chess.play(screen, speaker)
  chess.loadExperience()
  local board = chess.newBoard()
  local history = {}
  local whiteTurn = true
  local moveCount = 0

  screen.printSlow("CHESS SIMULATION INITIALIZED. You are White.")
  while true do
    screen.printSlow("Move " .. (moveCount+1) .. ":")
    for _,line in ipairs(chess._pretty(board)) do screen.printSlow(line, 0.002) end

    local winner = checkGameEnd(board)
    if winner then
      screen.printSlow("Game over: "..winner.." wins.")
      recordHistory(history, winner)
      return
    end

    if whiteTurn then
      while true do
        local s = screen.ask("Your move (format 'r c_r c', e.g. '7 2_5 2' or '72_52'):")
        local a,b,c,d = s:match("(%d)%s*(%d)%s*[_%s]%s*(%d)%s*(%d)")
        if not a then
          local p1,p2 = s:match("(%d%d)%s*_%s*(%d%d)")
          if p1 and p2 and #p1==2 and #p2==2 then
            a,b = p1:sub(1,1), p1:sub(2,2)
            c,d = p2:sub(1,1), p2:sub(2,2)
          end
        end
        if a then
          local fR,fC,tR,tC = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
          local moves = genMoves(board, true)
          local chosen = nil
          for _,mv in ipairs(moves) do
            if mv.fromR==fR and mv.fromC==fC and mv.toR==tR and mv.toC==tC then chosen = mv break end
          end
          if chosen then
            history[#history+1] = { boardKey = boardKey(board), move = chosen, white = true }
            board = applyMove(board, chosen)
            break
          else
            screen.printSlow("Illegal move. Try again.")
          end
        else
          screen.printSlow("Couldn't parse move. Try formats like '7 2_5 2' or '72_52'.")
        end
      end
    else
      screen.printSlow("WOPR thinking...")
      local mv = chooseMove(board, false)
      if not mv then
        screen.printSlow("WOPR has no legal moves. Stalemate/draw.")
        recordHistory(history, "draw")
        return
      end
      history[#history+1] = { boardKey = boardKey(board), move = mv, white = false }
      local label = string.format("%d%d -> %d%d", mv.fromR, mv.fromC, mv.toR, mv.toC)
      screen.printSlow("WOPR moves " .. label)
      board = applyMove(board, mv)
    end

    whiteTurn = not whiteTurn
    moveCount = moveCount + 1
    if moveCount > 300 then
      screen.printSlow("Draw by move limit.")
      recordHistory(history, "draw")
      return
    end
  end
end

return chess
