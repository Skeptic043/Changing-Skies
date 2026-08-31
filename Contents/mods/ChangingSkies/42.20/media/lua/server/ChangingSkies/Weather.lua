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

local function randomStormDuration(randomUnit)
    local value = tonumber(randomUnit())
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        value = 0.0
    elseif value < 0.0 then
        value = 0.0
    elseif value > 1.0 then
        value = 1.0
    end
    local count = Constants.RANDOM_STORM_DURATION_MAXIMUM -
        Constants.RANDOM_STORM_DURATION_MINIMUM + 1
    local offset = math.floor(value * count)
    if offset >= count then
        offset = count - 1
    end
    return Constants.RANDOM_STORM_DURATION_MINIMUM + offset
end

local function schedulerEnabled(settings)
    return settings.enableAddedWeather == true or (settings.stormProbability or 0.0) > 0.0
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

    if not schedulerEnabled(settings) then
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

local function verifiedStart(climateManager, state, successStatus, description)
    -- B42.20 can report trigger success even if WeatherPeriod initialization rejects it.
    if isRunning(climateManager) then
        state.lastWeatherRunning = true
        state.currentWeatherCreatedByChangingSkies = true
        state.schedulerStatus = "ACTIVE"
        Log.debug(description)
        return successStatus
    end

    state.currentWeatherCreatedByChangingSkies = false
    state.schedulerStatus = "ELIGIBLE"
    Log.once("weather-trigger-rejected", "Vanilla did not start the requested weather period; scheduler remains eligible.")
    return "TRIGGER_REJECTED"
end

local function chooseStormStage(settings, randomUnit)
    local stageId = Constants.STORM_STAGE_BY_TYPE[settings.stormType]
    if stageId ~= nil then
        return stageId
    end
    local index = math.floor(randomUnit() * #Constants.STORM_STAGE_BY_TYPE) + 1
    if index > #Constants.STORM_STAGE_BY_TYPE then
        index = #Constants.STORM_STAGE_BY_TYPE
    end
    return Constants.STORM_STAGE_BY_TYPE[index]
end

local function triggerStorm(climateManager, settings, state, randomUnit)
    if settings.stormType == 5 then
        climateManager:triggerCustomWeather(1.0, true)
        return verifiedStart(
            climateManager,
            state,
            "STORM_TRIGGERED",
            "Started a vanilla-generated seasonal weather pattern."
        )
    end

    local stageId = chooseStormStage(settings, randomUnit)
    local durationHours
    if settings.stormLength == 5 then
        durationHours = randomStormDuration(randomUnit)
    else
        durationHours = randomBetween(
            randomUnit,
            settings.stormDurationBand.minimum,
            settings.stormDurationBand.maximum
        )
    end
    climateManager:triggerCustomWeatherStage(stageId, durationHours)
    return verifiedStart(
        climateManager,
        state,
        "STORM_TRIGGERED",
        "Started vanilla storm stage " .. tostring(stageId) ..
            " for " .. tostring(durationHours) .. " hours."
    )
end

local function triggerOrdinaryWeather(climateManager, settings, state, randomUnit)
    local strength = randomBetween(
        randomUnit,
        settings.severityBand.minimum,
        settings.severityBand.maximum
    )
    local coldFront = randomUnit() < 0.5
    climateManager:triggerCustomWeather(strength, coldFront)
    return verifiedStart(
        climateManager,
        state,
        "TRIGGERED",
        "Started vanilla-generated weather at strength " .. tostring(strength) .. "."
    )
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

    local stormProbability = settings.stormProbability or 0.0
    if stormProbability > 0.0 and randomUnit() < stormProbability then
        return triggerStorm(climateManager, settings, state, randomUnit)
    end

    if settings.enableAddedWeather ~= true or randomUnit() >= settings.weatherProbability then
        return "ROLL_FAILED"
    end
    return triggerOrdinaryWeather(climateManager, settings, state, randomUnit)
end

ChangingSkies.Weather = Weather
