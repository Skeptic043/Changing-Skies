ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local Temperature = {
    ownsTemperature = false,
    ownsSnow = false,
}

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function lerp(factor, startValue, endValue)
    return startValue + (endValue - startValue) * factor
end

function Temperature.calculateDeltaC(coldAdjustmentF, warmAdjustmentF, airMassTemperature)
    local normalizedAirMass = clamp((airMassTemperature + 1.0) / 2.0, 0.0, 1.0)
    local deltaF = lerp(normalizedAirMass, coldAdjustmentF, warmAdjustmentF)
    return deltaF * 5.0 / 9.0
end

function Temperature.relinquish(temperatureFloat, snowBool)
    if Temperature.ownsTemperature then
        temperatureFloat:setEnableModded(false)
        Temperature.ownsTemperature = false
    end
    if Temperature.ownsSnow then
        snowBool:setEnableModded(false)
        Temperature.ownsSnow = false
    end
end

function Temperature.apply(climateManager, settings)
    local temperatureFloat = climateManager:getClimateFloat(ClimateManager.FLOAT_TEMPERATURE)
    local snowBool = climateManager:getClimateBool(ClimateManager.BOOL_IS_SNOW)

    if not settings.enableTemperatureAdjustment then
        Temperature.relinquish(temperatureFloat, snowBool)
        return { applied = false, reason = "disabled" }
    end

    if temperatureFloat:isEnableAdmin() then
        Temperature.relinquish(temperatureFloat, snowBool)
        Log.once("admin-temperature", "Administrator temperature override is active; relinquishing temperature and snow adjustment.")
        return { applied = false, reason = "admin" }
    end

    local pair, profileName = ChangingSkies.Settings.profileForSeason(
        settings,
        climateManager:getSeasonId()
    )
    local cleanValues = climateManager:getClimateValuesCopy()
    local vanillaTemperature = cleanValues:getTemperature()
    local airMassTemperature = cleanValues:getAirMassTemperature()
    local deltaC = Temperature.calculateDeltaC(pair.coldF, pair.warmF, airMassTemperature)
    local adjustedBase = clamp(
        vanillaTemperature + deltaC,
        Constants.TEMPERATURE_MIN_C,
        Constants.TEMPERATURE_MAX_C
    )

    temperatureFloat:setEnableModded(true)
    temperatureFloat:setModdedValue(adjustedBase)
    temperatureFloat:setModdedInterpolate(1.0)
    Temperature.ownsTemperature = true

    local correctedTemperature = adjustedBase
    local weatherPeriod = climateManager:getWeatherPeriod()
    if weatherPeriod and weatherPeriod:isRunning() and temperatureFloat:isEnableOverride() then
        -- WeatherPeriod refreshed this absolute target immediately before OnClimateTick.
        -- Shift that target too so its interpolation preserves the Changing Skies delta.
        local weatherInterpolation = clamp(temperatureFloat:getOverrideInterpolate(), 0.0, 1.0)
        local adjustedWeatherTarget = clamp(
            temperatureFloat:getOverride() + deltaC,
            Constants.TEMPERATURE_MIN_C,
            Constants.TEMPERATURE_MAX_C
        )
        temperatureFloat:setOverride(adjustedWeatherTarget, weatherInterpolation)
        correctedTemperature = lerp(weatherInterpolation, adjustedBase, adjustedWeatherTarget)
    end

    local winterChallengeSnow = ClimateManager.winterIsComing == true
    snowBool:setEnableModded(true)
    snowBool:setModdedValue(correctedTemperature < 0.0 or winterChallengeSnow)
    Temperature.ownsSnow = true

    Log.debug(
        profileName .. " delta=" .. tostring(deltaC) .. "C corrected=" ..
        tostring(correctedTemperature) .. "C"
    )
    return {
        applied = true,
        profileName = profileName,
        deltaC = deltaC,
        adjustedBase = adjustedBase,
        correctedTemperature = correctedTemperature,
    }
end

function Temperature.resetOwnershipForTests()
    Temperature.ownsTemperature = false
    Temperature.ownsSnow = false
end

ChangingSkies.Temperature = Temperature

