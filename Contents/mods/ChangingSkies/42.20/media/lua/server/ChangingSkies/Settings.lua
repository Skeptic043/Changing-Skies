ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local Settings = {
    lastValidTemperaturePairs = {},
}

local OPTION_NAMES = {
    "EnableAddedWeather",
    "AddedWeatherFrequency",
    "AddedWeatherSeverity",
    "CooldownMinimumHours",
    "CooldownMaximumHours",
    "EnableTemperatureAdjustment",
    "SpringColdEndAdjustmentF",
    "SpringWarmEndAdjustmentF",
    "SummerColdEndAdjustmentF",
    "SummerWarmEndAdjustmentF",
    "FallColdEndAdjustmentF",
    "FallWarmEndAdjustmentF",
    "WinterColdEndAdjustmentF",
    "WinterWarmEndAdjustmentF",
    "DebugLogging",
}

local function finiteNumber(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function integerInRange(value, minimum, maximum, fallback)
    local number = finiteNumber(value, fallback)
    number = math.floor(number)
    if number < minimum or number > maximum then
        return fallback
    end
    return number
end

local function validatePair(profile, coldF, warmF)
    local coldC = coldF * 5.0 / 9.0
    local warmC = warmF * 5.0 / 9.0
    if Constants.NOMINAL_AIR_MASS_SPREAD_C + warmC - coldC > 0.0 then
        local pair = { coldF = coldF, warmF = warmF }
        Settings.lastValidTemperaturePairs[profile] = pair
        return pair
    end

    Log.once(
        "invalid-temperature-" .. profile,
        "Invalid " .. profile .. " temperature endpoints; preserving the last valid pair or 0/0."
    )
    local previous = Settings.lastValidTemperaturePairs[profile]
    if previous then
        return { coldF = previous.coldF, warmF = previous.warmF }
    end
    return { coldF = 0.0, warmF = 0.0 }
end

local function readPair(source, profile)
    local cold = finiteNumber(source[profile .. "ColdEndAdjustmentF"], 0.0)
    local warm = finiteNumber(source[profile .. "WarmEndAdjustmentF"], 0.0)
    return validatePair(profile, cold, warm)
end

function Settings.readFromTable(source)
    source = type(source) == "table" and source or {}

    local minimumCooldown = finiteNumber(
        source.CooldownMinimumHours,
        Constants.DEFAULTS.cooldownMinimumHours
    )
    local maximumCooldown = finiteNumber(
        source.CooldownMaximumHours,
        Constants.DEFAULTS.cooldownMaximumHours
    )
    if minimumCooldown < 0.0 or maximumCooldown < minimumCooldown then
        Log.once(
            "invalid-cooldown",
            "Invalid added-weather cooldown range; using the conservative default range."
        )
        minimumCooldown = Constants.DEFAULTS.cooldownMinimumHours
        maximumCooldown = Constants.DEFAULTS.cooldownMaximumHours
    end

    local frequency = integerInRange(
        source.AddedWeatherFrequency,
        1,
        #Constants.WEATHER_PROBABILITIES,
        Constants.DEFAULTS.frequency
    )
    local severity = integerInRange(
        source.AddedWeatherSeverity,
        1,
        #Constants.SEVERITY_BANDS,
        Constants.DEFAULTS.severity
    )

    local result = {
        enableAddedWeather = source.EnableAddedWeather == true,
        frequency = frequency,
        weatherProbability = Constants.WEATHER_PROBABILITIES[frequency],
        severity = severity,
        severityBand = Constants.SEVERITY_BANDS[severity],
        cooldownMinimumHours = minimumCooldown,
        cooldownMaximumHours = maximumCooldown,
        enableTemperatureAdjustment = source.EnableTemperatureAdjustment == true,
        debugLogging = source.DebugLogging == true,
        temperatureProfiles = {
            Spring = readPair(source, "Spring"),
            Summer = readPair(source, "Summer"),
            Fall = readPair(source, "Fall"),
            Winter = readPair(source, "Winter"),
        },
    }
    Log.setDebugEnabled(result.debugLogging)
    return result
end

function Settings.read()
    local source = {}
    if type(SandboxVars) == "table" and type(SandboxVars.ChangingSkies) == "table" then
        for _, name in ipairs(OPTION_NAMES) do
            source[name] = SandboxVars.ChangingSkies[name]
        end
    end

    if type(getSandboxOptions) == "function" then
        local sandboxOptions = getSandboxOptions()
        if sandboxOptions ~= nil then
            for _, name in ipairs(OPTION_NAMES) do
                local option = sandboxOptions:getOptionByName("ChangingSkies." .. name)
                if option ~= nil then
                    local value = option:getValue()
                    if value ~= nil then
                        source[name] = value
                    end
                end
            end
        end
    end
    return Settings.readFromTable(source)
end

function Settings.profileForSeason(settings, seasonId)
    local profileName = Constants.SEASON_PROFILE_BY_ID[seasonId] or "Spring"
    return settings.temperatureProfiles[profileName], profileName
end

function Settings.resetValidationMemoryForTests()
    Settings.lastValidTemperaturePairs = {}
end

ChangingSkies.Settings = Settings
