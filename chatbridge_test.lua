-- chatbridge_diagnostics.lua
-- Diagnostic tool for ChatGPT bridge connectivity

local textutils = textutils
local http = http

-- CONFIG
local BRIDGE_URL = "http://YOUR_PC_IP:25594/wopr" -- replace with your bridge IP
local TEST_MESSAGE = "Ping WOPR"
local TIMEOUT = 10

-- Helper: Print status in a consistent format
local function report(name, ok, details)
    if ok then
        print("✅ "..name..": "..(details or "OK"))
    else
        print("❌ "..name..": "..(details or "Failed"))
    end
end

print("=== WOPR Bridge Diagnostics ===")
print("Testing bridge at: "..BRIDGE_URL)
print("")

-- 1️⃣ Check HTTP enabled
if not http then
    report("HTTP API enabled", false, "http_enable = false in cc-tweaked.cfg")
    print("Enable it and restart Minecraft, then retry.")
    return
else
    report("HTTP API enabled", true)
end

-- 2️⃣ Test if the bridge is reachable (simple GET)
local ok, h = pcall(http.get, BRIDGE_URL)
if ok and h then
    report("Bridge reachable (GET)", true)
    h.close()
else
    report("Bridge reachable (GET)", false, "Cannot reach "..BRIDGE_URL)
end

-- 3️⃣ Test POST request with JSON
local function testPOST()
    local body = '{"message":'..textutils.serializeJSON(TEST_MESSAGE)..'}'
    local headers = {["Content-Type"]="application/json"}

    local ok, resp = pcall(function()
        local h = http.post(BRIDGE_URL, body, headers)
        if not h then return nil, "http.post returned nil" end
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

local postOk, postResp = testPOST()
if postOk then
    report("POST request", true, "Received reply: "..(postResp:sub(1,60).."…"))
else
    report("POST request", false, tostring(postResp))
end

-- 4️⃣ Optional: Sanity check reply
if postOk then
    if postResp:find("Hello") or #postResp > 0 then
        report("Reply sanity check", true)
    else
        report("Reply sanity check", false, "Empty or invalid response")
    end
end

print("\nDiagnostics complete.")
print("If any step failed, check IP, port, firewall, or Python bridge status.")
