ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local Weather = {}

local function defaultRandomUnit()
    return ZombRand(Constants.RANDOM_SCALE) / Constants.RANDOM_SCALE
end

local function isRunning(climateManager)
    local weatherPeriod = climateManager:getWeatherPeriod()
    return weatherPeriod ~= nil and weatherPeriod:isRunning()
end

local function randomBetween(randomUnit, minimum, maximum)
    return minimum + (maximum - minimum) * randomUnit()
end

local function beginCooldown(settings, state, worldAgeHours, randomUnit)
    local cooldownHours = randomBetween(
        randomUnit,
        settings.cooldownMinimumHours,
        settings.cooldownMaximumHours
    )
    state.cooldownUntilWorldAgeHours = worldAgeHours + cooldownHours
    state.schedulerStatus = cooldownHours > 0.0 and "COOLDOWN" or "ELIGIBLE"
    Log.debug("Weather ended; cooldown set for " .. tostring(cooldownHours) .. " world hours.")
end

function Weather.reconcile(climateManager, settings, state, worldAgeHours, randomUnit)
    randomUnit = randomUnit or defaultRandomUnit
    local running = isRunning(climateManager)

    if not settings.enableAddedWeather then
        if not running or not state.lastWeatherRunning then
            state.currentWeatherCreatedByChangingSkies = false
        end
        state.lastWeatherRunning = running
        state.schedulerStatus = "DISABLED"
        return state.schedulerStatus
    end

    if running then
        if not state.lastWeatherRunning then
            state.currentWeatherCreatedByChangingSkies = false
        end
        state.lastWeatherRunning = true
        state.schedulerStatus = "ACTIVE"
        return state.schedulerStatus
    end

    if state.lastWeatherRunning then
        state.lastWeatherRunning = false
        state.currentWeatherCreatedByChangingSkies = false
        beginCooldown(settings, state, worldAgeHours, randomUnit)
        return state.schedulerStatus
    end

    state.currentWeatherCreatedByChangingSkies = false
    local deadline = state.cooldownUntilWorldAgeHours
    if deadline ~= nil and worldAgeHours < deadline then
        state.schedulerStatus = "COOLDOWN"
        return state.schedulerStatus
    end

    state.cooldownUntilWorldAgeHours = nil
    state.schedulerStatus = "ELIGIBLE"
    return state.schedulerStatus
end

function Weather.onTenMinutes(climateManager, settings, state, worldAgeHours, randomUnit)
    randomUnit = randomUnit or defaultRandomUnit
    local slot = math.floor(worldAgeHours * 6.0 + 0.000001)
    if state.lastProcessedTenMinuteSlot == slot then
        return "DUPLICATE"
    end
    state.lastProcessedTenMinuteSlot = slot

    local status = Weather.reconcile(climateManager, settings, state, worldAgeHours, randomUnit)
    if status ~= "ELIGIBLE" then
        return status
    end

    if randomUnit() >= settings.weatherProbability then
        return "ROLL_FAILED"
    end

    local strength = randomBetween(
        randomUnit,
        settings.severityBand.minimum,
        settings.severityBand.maximum
    )
    local coldFront = randomUnit() < 0.5
    climateManager:triggerCustomWeather(strength, coldFront)

    -- B42.20 can report trigger success even if WeatherPeriod initialization rejects it.
    if isRunning(climateManager) then
        state.lastWeatherRunning = true
        state.currentWeatherCreatedByChangingSkies = true
        state.schedulerStatus = "ACTIVE"
        Log.debug("Started vanilla-generated weather at strength " .. tostring(strength) .. ".")
        return "TRIGGERED"
    end

    state.currentWeatherCreatedByChangingSkies = false
    state.schedulerStatus = "ELIGIBLE"
    Log.once("weather-trigger-rejected", "Vanilla did not start the requested weather period; scheduler remains eligible.")
    return "TRIGGER_REJECTED"
end

ChangingSkies.Weather = Weather
