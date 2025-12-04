-- chatbridge.lua
-- Simple thin wrapper to call the local bridge server.
-- Configure BRIDGE_URL to your PC running wopr_bridge.py.

local http = http
local textutils = textutils

local BRIDGE_URL = "http://YOUR_PC_IP:5000/wopr"  -- <<<< replace YOUR_PC_IP, or set via env reading below if you prefer
-- Example: "http://192.168.1.12:5000/wopr"

local function chatGPT_bridge(message, timeoutSeconds)
  timeoutSeconds = timeoutSeconds or 10
  -- Ensure message is a string
  if type(message) ~= "string" then message = tostring(message) end
  local body = '{"message":' .. textutils.serializeJSON(message) .. '}'
  local headers = { ["Content-Type"] = "application/json" }

  local ok, resp = pcall(function()
    local h = http.post(BRIDGE_URL, body, headers)
    if not h then return nil, "http.post failed (no handle)" end
    -- set a soft timeout using os.startTimer if you want; readAll is blocking
    local txt = h.readAll()
    h.close()
    return txt
  end)

  if not ok then
    return nil, "HTTP error: " .. tostring(resp)
  end
  if not resp then return nil, "no response from bridge" end
  -- bridge returns plain text already
  return resp
end

return {
  chat = chatGPT_bridge
}
