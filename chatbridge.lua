-- chatbridge.lua
-- Thin wrapper to call the local ChatGPT bridge server
-- Can also be run standalone to test connectivity

local textutils = textutils
local http = http

-- CONFIG
local BRIDGE_URL = "http://YOUR_PC_IP:25594/wopr"  -- replace with your bridge IP

local function chatGPT_bridge(message)
    local body = '{"message":' .. textutils.serializeJSON(message) .. '}'
    local headers = { ["Content-Type"] = "application/json" }

    local ok, resp = pcall(function()
        local h = http.post(BRIDGE_URL, body, headers)
        if not h then return nil, "http.post failed" end
        local txt = h.readAll()
        h.close()
        return txt
    end)

    if not ok then
        return nil, "HTTP error: " .. tostring(resp)
    end
    return resp
end

-- Detect if the file is run directly
if not pcall(debug.getlocal, 1, 1) then
    -- Running directly
    print("=== Chatbridge Self-Test ===")
    print("Testing connection to bridge at: " .. BRIDGE_URL)
    local reply, err = chatGPT_bridge("Hello WOPR, test connectivity.")
    if reply then
        print("Success! Bridge reply:\n"..reply)
    else
        print("Failed to connect to bridge:\n"..tostring(err))
    end
    return
end

-- Module export
return {
    chat = chatGPT_bridge
}
