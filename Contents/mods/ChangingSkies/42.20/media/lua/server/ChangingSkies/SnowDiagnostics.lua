ChangingSkies = ChangingSkies or {}

local Log = ChangingSkies.Log
local SnowDiagnostics = {
    lastSlot = nil,
}

local UNAVAILABLE = "unavailable"

local function safeCall(target, methodName)
    if target == nil then
        return UNAVAILABLE
    end
    local method = target[methodName]
    if method == nil then
        return UNAVAILABLE
    end
    local value = method(target)
    if value == nil then
        return UNAVAILABLE
    end
    return value
end

local function cellSnowTarget()
    if getCell == nil then
        return UNAVAILABLE
    end
    local cell = getCell()
    if cell == nil then
        return UNAVAILABLE
    end
    return safeCall(cell, "getSnowTarget")
end

local function seasonFiveEligibleSafe(climateManager)
    local season = safeCall(climateManager, "getSeason")
    if season == UNAVAILABLE then
        return UNAVAILABLE
    end
    if season.isSeason == nil then
        return UNAVAILABLE
    end
    local eligible = season:isSeason(5)
    if eligible == nil then
        return UNAVAILABLE
    end
    return eligible
end

local function weatherRunning(climateManager)
    local period = safeCall(climateManager, "getWeatherPeriod")
    if period == UNAVAILABLE then
        return UNAVAILABLE
    end
    return safeCall(period, "isRunning")
end

local function temperatureFields(temperatureResult)
    temperatureResult = type(temperatureResult) == "table" and temperatureResult or {}
    if temperatureResult.applied ~= true then
        return "relinquished:" .. tostring(temperatureResult.reason or UNAVAILABLE),
            UNAVAILABLE,
            UNAVAILABLE
    end

    local corrected = temperatureResult.correctedTemperature
    local requestedSnow = UNAVAILABLE
    if type(corrected) == "number" and corrected == corrected and
        corrected ~= math.huge and corrected ~= -math.huge then
        requestedSnow = corrected < 0.0 or ClimateManager.winterIsComing == true
    end
    return "applied", corrected or UNAVAILABLE, requestedSnow
end

function SnowDiagnostics.emit(climateManager, settings, temperatureResult, worldAgeHours)
    if type(settings) ~= "table" or settings.debugLogging ~= true then
        return nil
    end

    local age = tonumber(worldAgeHours)
    if age == nil or age ~= age or age == math.huge or age == -math.huge then
        return nil
    end
    local slot = math.floor(age * 6.0)
    if SnowDiagnostics.lastSlot == slot then
        return nil
    end
    SnowDiagnostics.lastSlot = slot

    local temperatureStatus, correctedTemperature, requestedSnow =
        temperatureFields(temperatureResult)
    local line = table.concat({
        "SnowDiag",
        "previousCompletedTick.composedSnow=" ..
            tostring(safeCall(climateManager, "getPrecipitationIsSnow")),
        "previousCompletedTick.precipitationIntensity=" ..
            tostring(safeCall(climateManager, "getPrecipitationIntensity")),
        "previousCompletedTick.snowStrength=" ..
            tostring(safeCall(climateManager, "getSnowStrength")),
        "previousCompletedTick.snowFracNow=" ..
            tostring(safeCall(climateManager, "getSnowFracNow")),
        "previousCompletedTick.cellSnowTarget=" .. tostring(cellSnowTarget()),
        "previousCompletedTick.season5GroundRendererEligible=" ..
            tostring(seasonFiveEligibleSafe(climateManager)),
        "previousCompletedTick.weatherPeriodRunning=" ..
            tostring(weatherRunning(climateManager)),
        "newTick.csTemperatureStatus=" .. temperatureStatus,
        "newTick.csCorrectedTemperatureC=" .. tostring(correctedTemperature),
        "newTick.csRequestedSnowTarget=" .. tostring(requestedSnow),
    }, " ")
    Log.debug(line)
    return line
end

function SnowDiagnostics.resetForTests()
    SnowDiagnostics.lastSlot = nil
end

ChangingSkies.SnowDiagnostics = SnowDiagnostics
