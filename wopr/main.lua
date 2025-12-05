-----------------------------
-- WOPR MAIN (Integrated)
-- No require() — CC:Tweaked compatible
-- Chess + TTT loaded via dofile()
-----------------------------

-- Load game files (must return tables!)
local chess = dofile("wopr/chess.lua")
local ttt   = dofile("wopr/ttt.lua")

---------------------------------------------------
-- PERSISTENT MEMORY (integrated)
---------------------------------------------------

local memory = {}

local memFile = "wopr_memory.db"
local memData = {}

function memory.init()
    if fs.exists(memFile) then
        local h = fs.open(memFile, "r")
        memData = textutils.unserialize(h.readAll()) or {}
        h.close()
    else
        memory.save()
    end
end

function memory.save()
    local h = fs.open(memFile, "w")
    h.write(textutils.serialize(memData))
    h.close()
end

function memory.get(key)
    return memData[key]
end

function memory.set(key, val)
    memData[key] = val
    memory.save()
end


---------------------------------------------------
-- SCREEN SYSTEM (integrated)
---------------------------------------------------

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
end

local function typeSlow(str, rate)
    rate = rate or 0.03
    term.setCursorBlink(false)
    for c in str:gmatch(".") do
        write(c)
        sleep(rate)
    end
    term.setCursorBlink(true)
end

local function ask(str)
    typeSlow("\nWOPR: " .. str .. "\n> ")
    return read()
end


---------------------------------------------------
-- DIALOG SYSTEM (integrated)
---------------------------------------------------

local greetings = {
    "GREETINGS PROFESSOR.",
    "AH, PROFESSOR FALKEN.",
    "HELLO AGAIN, PROFESSOR."
}

local queries = {
    "SHALL WE PLAY A GAME?",
    "WOULD YOU LIKE A STRATEGIC SIMULATION?",
    "WHAT SHALL WE PLAY TODAY?"
}

local gameList = {
    "TIC-TAC-TOE",
    "CHESS"
}

local function startConversation(username)
    typeSlow("\nWOPR: "..greetings[math.random(#greetings)].."\n", 0.04)

    local response = ask(queries[math.random(#queries)])
    local lower = string.lower(response)

    if lower:find("tic") or lower:find("toe") then
        typeSlow("\nWOPR: EXCELLENT.\n")
        ttt.play()
        return
    end

    if lower:find("chess") then
        typeSlow("\nWOPR: INITIALIZING BOARD.\n")
        chess.start()
        return
    end

    typeSlow("\nWOPR: AVAILABLE OPTIONS:\n")
    for _,g in ipairs(gameList) do
        typeSlow(" - "..g.."\n")
    end
end


---------------------------------------------------
-- MAIN PROGRAM
---------------------------------------------------

math.randomseed(os.time() % 65536)
memory.init()

clear()
typeSlow("LOGON: >", 0.08)
local username = read()

typeSlow("\nVERIFYING...", 0.04)
sleep(1)
typeSlow("\nACCESS GRANTED.\n\n", 0.05)

while true do
    startConversation(username)
end
