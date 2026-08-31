ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local Thunder = {}

local function defaultRandomUnit()
    return ZombRand(Constants.RANDOM_SCALE) / Constants.RANDOM_SCALE
end

local function finiteNumber(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function playerCoordinates(player)
    if player == nil or player.getX == nil or player.getY == nil then
        return nil
    end
    local x = player:getX()
    local y = player:getY()
    if not finiteNumber(x) or not finiteNumber(y) then
        return nil
    end
    return { player = player, x = x, y = y }
end

local function appendPlayer(players, player)
    local candidate = playerCoordinates(player)
    if candidate ~= nil then
        players[#players + 1] = candidate
    end
end

local function collectPlayers()
    local players = {}
    if type(isServer) == "function" and isServer() then
        if type(getOnlinePlayers) ~= "function" then
            return players
        end
        local online = getOnlinePlayers()
        if online == nil or online.size == nil or online.get == nil then
            return players
        end
        for index = 0, online:size() - 1 do
            appendPlayer(players, online:get(index))
        end
        return players
    end

    if type(getNumActivePlayers) ~= "function" or
        type(getSpecificPlayer) ~= "function" then
        return players
    end
    local count = tonumber(getNumActivePlayers()) or 0
    for index = 0, math.max(0, math.floor(count)) - 1 do
        appendPlayer(players, getSpecificPlayer(index))
    end
    return players
end

local function runningWeatherPeriod(climateManager)
    local weatherPeriod = climateManager:getWeatherPeriod()
    if weatherPeriod ~= nil and weatherPeriod:isRunning() then
        return weatherPeriod
    end
    return nil
end

local function scopeAllows(period, scope)
    if scope == 2 then
        return Constants.THUNDER_STAGE_IDS[period:getCurrentStageID()] == true
    end
    if scope == 3 then
        return period:isThunderStorm() or period:isTropicalStorm()
    end
    return true
end

local function roundInteger(value)
    if value >= 0.0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function Thunder.onClimateTick(climateManager, settings, state, worldAgeHours, randomUnit)
    randomUnit = randomUnit or defaultRandomUnit
    local age = tonumber(worldAgeHours)
    if not finiteNumber(age) then
        return "INVALID_TIME"
    end

    local slot = math.floor(age * 60.0 + 0.000001)
    if state.lastProcessedThunderMinuteSlot == slot then
        return "DUPLICATE"
    end
    state.lastProcessedThunderMinuteSlot = slot

    local probability = settings.addedThunderProbability or 0.0
    if probability <= 0.0 then
        return "DISABLED"
    end
    local period = runningWeatherPeriod(climateManager)
    if period == nil then
        return "NO_WEATHER"
    end
    if not scopeAllows(period, settings.addedThunderScope or 1) then
        return "OUT_OF_SCOPE"
    end
    if randomUnit() >= probability then
        return "ROLL_FAILED"
    end

    local thunderSystem = climateManager:getThunderStorm()
    if thunderSystem == nil or thunderSystem.triggerThunderEvent == nil then
        return "MISSING_SYSTEM"
    end

    local players = collectPlayers()
    if #players == 0 then
        return "NO_PLAYER"
    end
    local playerIndex = math.floor(randomUnit() * #players) + 1
    if playerIndex > #players then
        playerIndex = #players
    end
    local targetPlayer = players[playerIndex]
    local angle = randomUnit() * math.pi * 2.0
    local distance = Constants.THUNDER_MINIMUM_DISTANCE +
        (Constants.THUNDER_MAXIMUM_DISTANCE - Constants.THUNDER_MINIMUM_DISTANCE) *
        randomUnit()
    local x = roundInteger(targetPlayer.x + math.cos(angle) * distance)
    local y = roundInteger(targetPlayer.y + math.sin(angle) * distance)

    thunderSystem:triggerThunderEvent(x, y, true, false, false)
    Log.debug("Added sound-only thunder at " .. tostring(x) .. "," .. tostring(y) .. ".")
    return "TRIGGERED", x, y
end

ChangingSkies.Thunder = Thunder
