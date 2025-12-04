-- RUN
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
    local input = read()
    if not input then break end
    input = input:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if input == "help" then
      showHelp()

    elseif input == "play ttt" then
      dashboard.mode="TTT"
      dashboardLog("Started Tic-Tac-Toe")
      updateDashboard()
      playTTT()
      dashboard.mode="IDLE"
      dashboardLog("Returned to IDLE")
      updateDashboard()

    elseif input == "status" then
      status()

    elseif input == "quit" or input == "exit" then
      say("Goodbye.")
      break

    else
      -- Treat as chat
      dashboard.mode="TALK"
      dashboardLog("User sent chat message")
      updateDashboard()

      local intent = detectIntent(input)
      local resp = pickResponse(responses[intent] or responses.smalltalk)
      say("WOPR: "..resp)
      dashboardLog("Local AI replied (intent: "..intent..")")
      updateDashboard()

      if intent == "play" then
        dashboard.mode="TTT"
        dashboardLog("Starting Tic-Tac-Toe from chat")
        updateDashboard()
        playTTT()
        dashboard.mode="IDLE"
        dashboardLog("Returned to IDLE")
        updateDashboard()
      end
    end
  end
end

boot()
