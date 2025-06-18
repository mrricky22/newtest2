local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Discord webhook URL
local webhookUrl = "https://discord.com/api/webhooks/1384910804377141338/PYYqx9758hsp5r3H88andR5dj4xAQ_LI517F5VbRpYAvEF7kqDF1rndYJURVR26tsXBr"

-- Script to run after teleport
local scriptToRun = [[
    -- Wait until the game is fully loaded
    game.Loaded:Wait()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/mrricky22/newtest2/refs/heads/main/new.lua"))()
]]

-- Function to send Discord webhook
local function sendWebhook(message)
    local requestOptions = {
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({
            content = message
        })
    }
    
    local success, response = pcall(function()
        return request(requestOptions)
    end)
    
    if not success then
        warn("Failed to send webhook: " .. tostring(response))
    end
end

-- Function to get a random server
local function getRandomServer()
    local url = "https://games.roblox.com/v1/games/606849621/servers/Public?limit=100&sortOrder=Desc&excludeFullGames=true"
    local requestOptions = {
        Url = url,
        Method = "GET"
    }
    
    local success, response = pcall(function()
        return request(requestOptions)
    end)
    
    if success and response.Success then
        local data = HttpService:JSONDecode(response.Body)
        local servers = data.data
        if #servers > 0 then
            local randomIndex = math.random(1, #servers)
            return servers[randomIndex].id
        end
    else
        warn("Failed to fetch servers: " .. tostring(response))
    end
    return nil
end

-- Main logic
local function checkWorkspaceAndAct()
    local dropCount = 0
    
    -- Search workspace for "Drop" with "Walls" child and count instances
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Drop" and child:FindFirstChild("Walls") then
            dropCount = dropCount + 1
        end
    end
    
    -- Send webhook with count of drops found
    local message = string.format(
        "Found %d airdrop(s) in server: https://fern.wtf/joiner?placeId=606849621&gameInstanceId=%s",
        dropCount,
        game.JobId
    )
    sendWebhook(message)
    
    -- Hop to a random server regardless of findings
    local serverId = getRandomServer()
    if serverId then
        queue_on_teleport(scriptToRun)
        TeleportService:TeleportToPlaceInstance(606849621, serverId)
    else
        warn("No available servers found.")
    end
end

-- Execute the main logic
checkWorkspaceAndAct()
