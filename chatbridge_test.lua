-- chatbridge_test.lua
-- Full-featured standalone test program for ChatGPT bridge

local textutils = textutils
local http = http

-- CONFIG: Update to your bridge IP/port
local BRIDGE_URL = "http://YOUR_PC_IP:25594/wopr"
local RETRIES = 3
local TEST_MESSAGE = "Hello WOPR, testing connectivity."
local TIMEOUT = 10 -- seconds

-- Helper: Send a message to bridge
local function sendTest(msg)
    local body = '{"message":' .. textutils.serializeJSON(msg) .. '}'
    local headers = { ["Content-Type"] = "application/json" }

    local ok, resp = pcall(function()
        local h = http.post(BRIDGE_URL, body, headers)
        if not h then return nil, "http.post failed" end
        local txt = h.readAll()
        h.close()
        return txt
    end)

    if ok and resp then
        return true, resp
    else
        return false, resp
    end
end

-- Test loop with retries
print("=== Chatbridge Full Test ===")
print("Bridge URL: " .. BRIDGE_URL)

for attempt = 1, RETRIES do
    print(string.format("Attempt %d of %d...", attempt, RETRIES))
    local startTime = os.clock()
    local success, respOrErr = sendTest(TEST_MESSAGE)
    local elapsed = os.clock() - startTime

    if success then
        print(string.format("✅ Success! Time: %.2f sec", elapsed))
        print("Bridge reply:\n" .. respOrErr)
        break
    else
        print(string.format("❌ Failed (%.2f sec): %s", elapsed, tostring(respOrErr)))
        if attempt == RETRIES then
            print("All attempts failed. Check your bridge or network settings.")
        else
            print("Retrying...")
        end
    end
end

-- Extra check for HTTP enabled in CC:Tweaked
if not http then
    print("\n⚠️ HTTP API not available in CC:Tweaked. Ensure 'http_enable = true' in cc-tweaked.cfg")
end
