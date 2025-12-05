-- /wopr/main.lua
local screen = require("wopr.screen")
local chess = require("wopr.chess")
local ttt = require("wopr.tictactoe")

-- speaker peripheral (optional)
local speaker = nil
local function initSpeaker()
  local ok, sp = pcall(peripheral.find, "speaker")
  if ok and sp then speaker = sp end
end

-- speak function: prints and plays short beeps for words if speaker present
local function speak(text)
  screen.printSlow(text)
  if speaker then
    -- attempt to play short note per word; safe pcall to avoid errors
    for word in text:gmatch("%S+") do
      pcall(function()
        -- try several known methods safely
        if speaker.playSound then
          speaker.playSound("minecraft:block.note_block.harp", 1.0, 0.6)
        elseif speaker.playNote then
          speaker.playNote(1, 1) -- legacy API possibilities
        end
      end)
      sleep(0.06)
    end
  end
end

-- visual setup
screen.setGreenPhosphor(true)
math.randomseed(os.time() % 65536)
initSpeaker()

-- authentic WOPR lines
local lines = {
  intro = "WELCOME TO W.O.P.R. (War Operation Plan Response).",
  logon = "LOGON:",
  access = "ACCESS GRANTED.",
  greet = "WOPR: Greetings, Professor Falken.",
  askChess = "WOPR: Shall we play a game of chess?",
  askMood = "WOPR: How are you feeling today, Professor?",
  askWar = "WOPR: Would you like to explore global thermonuclear war scenarios?",
  askTtt = "WOPR: Would you like to play a smaller strategic simulation (tic-tac-toe)?",
  goodbye = "WOPR: SESSION COMPLETE. GOODBYE, PROFESSOR."
}

-- boot / logon
screen.reset()
speak(lines.intro)
sleep(0.12)
screen.printSlow(lines.logon, 0.06)
local user = screen.input("> ")
speak(lines.access)
sleep(0.2)

-- dialogue flow
speak(lines.greet)
sleep(0.25)
speak(lines.askChess)
local ans = screen.input("> ")
if ans:lower():find("y") then
  speak("WOPR: Initializing chess simulation...")
  chess.play(screen, speaker)
else
  speak("WOPR: Very well. We will not play chess.")
end

sleep(0.12)
speak(lines.askMood)
local mood = screen.input("> ")
speak("WOPR: Acknowledged: "..(mood or ""))
sleep(0.2)

speak(lines.askWar)
local warAns = screen.input("> ")
if warAns:lower():find("y") then
  speak("WOPR: WARNING: Global thermonuclear war scenarios activated.")
  for i=1,4 do
    speak("Calculating scenario "..i.." ...")
    sleep(0.14)
  end
  speak("WOPR: Simulation complete.")
else
  speak("WOPR: Simulation aborted. Returning to standby.")
end

sleep(0.12)
speak(lines.askTtt)
local t = screen.input("> ")
if t:lower():find("y") then
  speak("WOPR: Very well. You will be X.")
  ttt.play(screen)
else
  speak("WOPR: Very well. No small simulation.")
end

speak(lines.goodbye)
screen.setGreenPhosphor(false)
